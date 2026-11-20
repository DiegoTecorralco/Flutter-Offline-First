class Task {
  const Task({required this.id, required this.title, required this.completed,
    required this.updatedAt, required this.version, required this.isSynced,
    required this.isDeleted});

  final String id;
  final String title;
  final bool completed;
  final DateTime updatedAt;
  final int version;
  final bool isSynced;
  final bool isDeleted;

  Task change({String? title, bool? completed, bool? isSynced,
    bool? isDeleted, DateTime? updatedAt, int? version}) => Task(
      id: id, title: title ?? this.title, completed: completed ?? this.completed,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt, version: version ?? this.version);

  Map<String, Object?> toRow() => {
    'id': id, 'title': title, 'completed': completed ? 1 : 0,
    'is_synced': isSynced ? 1 : 0, 'is_deleted': isDeleted ? 1 : 0,
    'updated_at': updatedAt.toUtc().toIso8601String(), 'version': version,
  };

  factory Task.fromRow(Map<String, Object?> row) => Task(
    id: row['id'] as String, title: row['title'] as String,
    completed: row['completed'] == 1, isSynced: row['is_synced'] == 1,
    isDeleted: row['is_deleted'] == 1,
    updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    version: (row['version'] as num).toInt());

  Map<String, dynamic> toCloud() => {
    'title': title, 'completed': completed, 'is_deleted': isDeleted,
    'updated_at': updatedAt.toUtc().toIso8601String(), 'version': version,
  };

  factory Task.fromCloud(String id, Map<String, dynamic> map) => Task(
    id: id, title: map['title'] as String, completed: map['completed'] as bool,
    isDeleted: map['is_deleted'] as bool, isSynced: true,
    updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    version: (map['version'] as num).toInt());
}
