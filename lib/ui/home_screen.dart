import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local_store.dart';
import '../model/task.dart';
import '../services/background_sync.dart';
import '../services/session_service.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final store = LocalStore.instance;
  final sync = SyncService.instance;
  List<Task> tasks = [];
  String message = 'Cargando SQLite…';
  StreamSubscription<void>? updates;
  StreamSubscription<String>? statuses;

  @override
  void initState() {
    super.initState();
    updates = store.changed.listen((_) => _refresh());
    statuses = sync.status.listen((status) {
      if (mounted) setState(() => message = status);
    });
    _refresh();
    sync.start();
  }

  Future<void> _refresh() async {
    final list = await store.visible();
    if (mounted) setState(() => tasks = list);
  }

  Future<void> _write({Task? original, String? title, bool? completed,
      bool deleted = false}) async {
    final now = DateTime.now().toUtc();
    final record = original == null
        ? Task(id: const Uuid().v4(), title: title!.trim(), completed: false,
            isDeleted: false, isSynced: false, updatedAt: now, version: 1)
        : original.change(title: title, completed: completed,
            isDeleted: deleted ? true : null, isSynced: false,
            updatedAt: now.isAfter(original.updatedAt)
                ? now : original.updatedAt.add(const Duration(microseconds: 1)),
            version: original.version + 1);
    await store.save(record); // primero disco; la UI solo lee de SQLite
    await scheduleRetry();
    unawaited(sync.sync());
  }

  Future<void> _showEditor([Task? original]) async {
    final controller = TextEditingController(text: original?.title ?? '');
    final value = await showDialog<String>(context: context, builder: (ctx) =>
      AlertDialog(title: Text(original == null ? 'Crear tarea' : 'Editar tarea'),
        content: TextField(controller: controller, autofocus: true,
          maxLength: 120, decoration: const InputDecoration(labelText: 'Título')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'))]));
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) {
      await _write(original: original, title: value);
    }
  }

  Future<void> _closeSession() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(title: const Text('Cerrar sesión'),
        content: const Text('Se borrarán todos los datos SQLite de esta sesión. '
          'Los registros ya sincronizados seguirán en la nube.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar y limpiar'))]));
    if (confirmed != true) return;
    await SessionService.instance.logoutAndPurge();
    if (mounted) setState(() => message = 'Sesión cerrada, datos locales eliminados');
  }

  @override
  void dispose() {
    updates?.cancel();
    statuses?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Semana 11 · Offline First'), actions: [
      IconButton(tooltip: 'Sincronizar', icon: const Icon(Icons.sync),
        onPressed: () => sync.sync()),
      IconButton(tooltip: 'Cerrar sesión y limpiar SQLite',
        icon: const Icon(Icons.logout), onPressed: _closeSession),
    ]),
    body: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text('$message · ${tasks.where((t) => !t.isSynced).length} pendientes')),
      Expanded(child: tasks.isEmpty
        ? const Center(child: Text('Sin tareas. Presiona + para crear una.'))
        : ListView.builder(itemCount: tasks.length, itemBuilder: (ctx, i) {
          final task = tasks[i];
          return ListTile(key: ValueKey(task.id),
            leading: Checkbox(value: task.completed,
              onChanged: (v) => _write(original: task, completed: v)),
            title: Text(task.title, style: TextStyle(decoration: task.completed
              ? TextDecoration.lineThrough : null)),
            subtitle: Text(task.isSynced ? '☁ Sincronizada' : '◷ Pendiente'),
            trailing: PopupMenuButton<String>(onSelected: (action) {
              if (action == 'edit') _showEditor(task);
              if (action == 'delete') _write(original: task, deleted: true);
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar'))]));
        })),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _showEditor(), icon: const Icon(Icons.add),
      label: const Text('Nueva tarea')),
  );
}
