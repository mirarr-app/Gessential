class Note {
  final int? id;
  final String content;
  final DateTime createdAt;
  final List<String> tags;

  Note({
    this.id,
    required this.content,
    DateTime? createdAt,
    List<String>? tags,
  })  : createdAt = createdAt ?? DateTime.now(),
        tags = tags ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'tags': tags.join(','),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final tagsString = map['tags'] as String?;
    final tagsList =
        tagsString?.isNotEmpty == true ? tagsString!.split(',') : <String>[];

    return Note(
      id: map['id'] as int,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      tags: tagsList,
    );
  }
}
