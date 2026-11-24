/// 笔记数据模型
class Note {
  final int? id;
  final String title;
  final String body;
  final int? categoryId;
  final bool isFavorite;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    this.id,
    required this.title,
    required this.body,
    this.categoryId,
    this.isFavorite = false,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 新建一条空白笔记
  factory Note.empty({int? categoryId}) {
    final now = DateTime.now();
    return Note(
      title: '',
      body: '',
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? body,
    int? categoryId,
    bool? isFavorite,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearImagePath = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      categoryId: categoryId ?? this.categoryId,
      isFavorite: isFavorite ?? this.isFavorite,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 转数据库行
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
      'category_id': categoryId,
      'is_favorite': isFavorite ? 1 : 0,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 从数据库行构造
  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      categoryId: map['category_id'] as int?,
      isFavorite: (map['is_favorite'] as int?) == 1,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse((map['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse((map['updated_at'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }
}
