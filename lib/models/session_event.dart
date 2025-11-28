/// Represents an event that occurred during an agent session.
class SessionEvent {
  final String id;
  final String sessionId;
  final SessionEventType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  SessionEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'type': type.name,
        'payload': payload,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      type: SessionEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SessionEventType.log,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Types of events that can occur during a session.
enum SessionEventType {
  plan,
  log,
  diff,
  action,
  toolResult,
  error,
  cancelled,
}
