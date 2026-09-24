import 'dart:convert';

class BlockList {
  final String id;
  String name;
  List<String> apps;

  BlockList({
    required this.id,
    required this.name,
    List<String>? apps,
  }) : apps = apps ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'apps': apps,
    };
  }

  factory BlockList.fromMap(Map<String, dynamic> map) {
    return BlockList(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      apps: List<String>.from(map['apps'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory BlockList.fromJson(String source) => BlockList.fromMap(json.decode(source));
}
