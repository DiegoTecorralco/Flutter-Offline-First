import 'package:flutter_test/flutter_test.dart';
import 'package:semana11_offline_first/model/task.dart';
import 'package:semana11_offline_first/services/sync_service.dart';

void main() {
  final when = DateTime.utc(2026, 11, 19, 12);
  Task task({DateTime? time, int version = 1, bool deleted = false}) => Task(
    id: 'uuid-1', title: 'Prueba', completed: false,
    isDeleted: deleted, isSynced: false, updatedAt: time ?? when,
    version: version);

  test('modelo persiste banderas y timestamp en SQLite', () {
    final saved = Task.fromRow(task().toRow());
    expect(saved.id, 'uuid-1');
    expect(saved.isSynced, false);
    expect(saved.updatedAt, when);
  });

  test('Last Write Wins prioriza la marca temporal UTC', () {
    expect(compareTaskChanges(task(time: when.add(const Duration(seconds: 1))),
        task(version: 99)), greaterThan(0));
  });

  test('empate en timestamp se decide por version', () {
    expect(compareTaskChanges(task(version: 2), task(version: 1)), greaterThan(0));
  });

  test('soft delete conserva ID y se propaga en la nube', () {
    final deleted = task().change(isDeleted: true, isSynced: false, version: 2);
    expect(deleted.id, 'uuid-1');
    expect(deleted.toCloud()['is_deleted'], true);
  });
}
