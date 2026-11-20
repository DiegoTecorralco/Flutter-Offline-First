import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../model/task.dart';

class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  Database? _database;
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;

  Future<Database> get db async => _database ??= await openDatabase(
    join(await getDatabasesPath(), 'offline_first_11.db'), version: 1,
    onCreate: (database, _) async => database.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY, title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1
      )'''));

  Future<List<Task>> visible() async => (await (await db).query('tasks',
    where: 'is_deleted = 0', orderBy: 'updated_at DESC'))
    .map(Task.fromRow).toList();

  Future<List<Task>> pending() async => (await (await db).query('tasks',
    where: 'is_synced = 0')).map(Task.fromRow).toList();

  Future<Task?> find(String id) async {
    final rows = await (await db).query('tasks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Task.fromRow(rows.first);
  }

  Future<void> save(Task item) async {
    await (await db).insert('tasks', item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace);
    _changed.add(null);
  }

  Future<void> acknowledge(Task sent) async {
    await (await db).update('tasks', {'is_synced': 1},
      where: 'id = ? AND version = ? AND updated_at = ? AND is_synced = 0',
      whereArgs: [sent.id, sent.version, sent.updatedAt.toUtc().toIso8601String()]);
    _changed.add(null);
  }

  Future<void> purge() async {
    await (await db).delete('tasks');
    _changed.add(null);
  }
}
