/// Represents a local project that can be managed by agents.
class Project {
  final String id;
  final String name;
  final String path;

  const Project({
    required this.id,
    required this.name,
    required this.path,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
    );
  }
}
