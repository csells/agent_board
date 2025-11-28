/// Represents an ACP-based coding agent.
class Agent {
  final String id;
  final String name;
  final AgentStatus status;

  const Agent({
    required this.id,
    required this.name,
    this.status = AgentStatus.available,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
      };

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String,
      status: AgentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AgentStatus.available,
      ),
    );
  }
}

enum AgentStatus {
  available,
  busy,
  offline,
}
