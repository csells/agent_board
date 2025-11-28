import 'session_event.dart';

/// Represents an agent session for a specific project and prompt.
class Session {
  final String id;
  final String agentId;
  final String projectId;
  final String prompt;
  SessionState state;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<SessionEvent> events = [];

  Session({
    required this.id,
    required this.agentId,
    required this.projectId,
    required this.prompt,
    this.state = SessionState.running,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentId': agentId,
        'projectId': projectId,
        'prompt': prompt,
        'state': state.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      projectId: json['projectId'] as String,
      prompt: json['prompt'] as String,
      state: SessionState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => SessionState.running,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

enum SessionState {
  running,
  done,
  failed,
  cancelled,
}
