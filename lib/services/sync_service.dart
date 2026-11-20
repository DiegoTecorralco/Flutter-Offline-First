import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/local_store.dart';
import '../model/task.dart';
import 'session_service.dart';

class SyncService {
  SyncService._();
  static final instance = SyncService._();
  final store = LocalStore.instance;
  final _status = StreamController<String>.broadcast();
  Stream<String> get status => _status.stream;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  Future<void>? _inProgress;

  void start() {
    _networkSubscription ??= Connectivity().onConnectivityChanged.listen((types) {
      if (types.contains(ConnectivityResult.none)) {
        _status.add('Sin red: guardando en SQLite');
      } else {
        unawaited(sync());
      }
    });
    unawaited(sync());
  }

  // Un solo ciclo a la vez: impide envios simultaneos y ACK incorrectos.
  Future<void> sync() => _inProgress ??= _run().whenComplete(() => _inProgress = null);

  Future<void> _run() async {
    try {
      if ((await Connectivity().checkConnectivity()).contains(ConnectivityResult.none)) {
        _status.add('Sin red: guardando en SQLite');
        return;
      }
      _status.add('Sincronizando: PUSH → ACK → PULL → MERGE');
      final user = await SessionService.instance.ensureUser();
      final firestore = FirebaseFirestore.instance;
      final tasks = firestore.collection('users').doc(user.uid).collection('tasks');

      // PUSH: cada UUID corresponde a un documento; reintentar es idempotente.
      for (final outgoing in await store.pending()) {
        final won = await firestore.runTransaction<bool>((tx) async {
          final ref = tasks.doc(outgoing.id);
          final snapshot = await tx.get(ref);
          if (snapshot.exists) {
            final remote = Task.fromCloud(outgoing.id, snapshot.data()!);
            // LWW determinista si timestamps coinciden: mayor version gana.
            if (compareTaskChanges(remote, outgoing) > 0) return false;
          }
          tx.set(ref, outgoing.toCloud());
          return true;
        });
        if (won) await store.acknowledge(outgoing);
      }

      // PULL desde servidor; la cache de Firestore no cuenta como confirmacion.
      final downloaded = await tasks.get(const GetOptions(source: Source.server));
      for (final document in downloaded.docs) {
        final remote = Task.fromCloud(document.id, document.data());
        final local = await store.find(remote.id);
        if (local == null || compareTaskChanges(remote, local) > 0 ||
            (compareTaskChanges(remote, local) == 0 && local.isSynced)) {
          // El registro ganador conserva el tombstone si fue eliminado.
          await store.save(remote);
        }
      }
      final pending = await store.pending();
      _status.add(pending.isEmpty ? 'Sincronizado con la nube'
          : '${pending.length} cambios pendientes');
    } catch (e) {
      _status.add('Sincronización pendiente: revisa red y Firebase');
    }
  }
}

// Comparador LWW estable. En un empate, solo version superior gana.
int compareTaskChanges(Task a, Task b) {
  final byTime = a.updatedAt.compareTo(b.updatedAt);
  return byTime != 0 ? byTime : a.version.compareTo(b.version);
}
