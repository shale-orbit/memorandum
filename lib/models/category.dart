/// 分类数据模型
class Category {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    required this.createdAt,
  });

  /// 系统预置的"未分类"名称，删除分类时其下笔记移入此分类
  static const String uncategorized = '未分类';

  Category copyWith({int? id, String? name, DateTime? createdAt}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      createdAt: DateTime.parse(
          (map['created_at'] as String?) ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isUncategorized => name == uncategorized;
}
