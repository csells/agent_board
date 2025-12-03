import 'package:json_annotation/json_annotation.dart';

part 'events.g.dart';

/// Base class for all Claude Code streaming events.
sealed class ClaudeEvent {
  const ClaudeEvent();

  /// Parse a JSONL line into a typed event.
  static ClaudeEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'init' => ClaudeInitEvent.fromJson(json),
      'message' => ClaudeMessageEvent.fromJson(json),
      'tool_use' => ClaudeToolUseEvent.fromJson(json),
      'tool_result' => ClaudeToolResultEvent.fromJson(json),
      'result' => ClaudeResultEvent.fromJson(json),
      'error' => ClaudeErrorEvent.fromJson(json),
      'system' => ClaudeSystemEvent.fromJson(json),
      'stream_event' => ClaudeStreamDeltaEvent.fromJson(json),
      _ => null,
    };
  }
}

/// Session initialization event - first event emitted.
@JsonSerializable()
final class ClaudeInitEvent extends ClaudeEvent {
  const ClaudeInitEvent({
    required this.sessionId,
    this.timestamp,
  });

  @JsonKey(name: 'session_id')
  final String sessionId;

  final String? timestamp;

  factory ClaudeInitEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeInitEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeInitEventToJson(this);
}

/// Message event - assistant or user content.
@JsonSerializable()
final class ClaudeMessageEvent extends ClaudeEvent {
  const ClaudeMessageEvent({
    required this.role,
    required this.content,
    this.partial,
  });

  final ClaudeMessageRole role;
  final List<ClaudeContentBlock> content;

  /// True if this is a partial/streaming message.
  final bool? partial;

  factory ClaudeMessageEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeMessageEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeMessageEventToJson(this);
}

/// Message role.
enum ClaudeMessageRole {
  @JsonValue('assistant')
  assistant,
  @JsonValue('user')
  user,
}

/// Content block within a message.
@JsonSerializable()
class ClaudeContentBlock {
  const ClaudeContentBlock({
    required this.type,
    this.text,
    this.id,
    this.name,
    this.input,
  });

  final ClaudeContentBlockType type;
  final String? text;

  /// For tool_use content blocks.
  final String? id;
  final String? name;
  final Map<String, dynamic>? input;

  factory ClaudeContentBlock.fromJson(Map<String, dynamic> json) =>
      _$ClaudeContentBlockFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeContentBlockToJson(this);
}

/// Content block type.
enum ClaudeContentBlockType {
  @JsonValue('text')
  text,
  @JsonValue('tool_use')
  toolUse,
}

/// Tool use event - tool invocation request.
@JsonSerializable()
final class ClaudeToolUseEvent extends ClaudeEvent {
  const ClaudeToolUseEvent({
    required this.id,
    required this.name,
    required this.input,
  });

  final String id;
  final String name;
  final Map<String, dynamic> input;

  factory ClaudeToolUseEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeToolUseEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeToolUseEventToJson(this);
}

/// Tool result event - tool execution result.
@JsonSerializable()
final class ClaudeToolResultEvent extends ClaudeEvent {
  const ClaudeToolResultEvent({
    required this.toolUseId,
    this.content,
    this.isError,
  });

  @JsonKey(name: 'tool_use_id')
  final String toolUseId;

  final String? content;

  @JsonKey(name: 'is_error')
  final bool? isError;

  factory ClaudeToolResultEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeToolResultEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeToolResultEventToJson(this);
}

/// Result event - session completion status.
@JsonSerializable()
final class ClaudeResultEvent extends ClaudeEvent {
  const ClaudeResultEvent({
    required this.status,
    this.sessionId,
    this.durationMs,
  });

  final ClaudeResultStatus status;

  @JsonKey(name: 'session_id')
  final String? sessionId;

  @JsonKey(name: 'duration_ms')
  final int? durationMs;

  factory ClaudeResultEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeResultEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeResultEventToJson(this);
}

/// Result status values.
enum ClaudeResultStatus {
  @JsonValue('success')
  success,
  @JsonValue('error')
  error,
  @JsonValue('cancelled')
  cancelled,
}

/// Error event.
@JsonSerializable()
final class ClaudeErrorEvent extends ClaudeEvent {
  const ClaudeErrorEvent({
    required this.error,
  });

  final ClaudeErrorDetail error;

  factory ClaudeErrorEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeErrorEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeErrorEventToJson(this);
}

/// Error detail.
@JsonSerializable()
class ClaudeErrorDetail {
  const ClaudeErrorDetail({
    this.type,
    this.message,
  });

  final String? type;
  final String? message;

  factory ClaudeErrorDetail.fromJson(Map<String, dynamic> json) =>
      _$ClaudeErrorDetailFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeErrorDetailToJson(this);
}

/// System event - system information and markers.
@JsonSerializable()
final class ClaudeSystemEvent extends ClaudeEvent {
  const ClaudeSystemEvent({
    required this.subtype,
    this.version,
    this.cwd,
    this.tools,
    this.compactMetadata,
  });

  final ClaudeSystemSubtype subtype;
  final String? version;
  final String? cwd;
  final List<String>? tools;

  @JsonKey(name: 'compact_metadata')
  final ClaudeCompactMetadata? compactMetadata;

  factory ClaudeSystemEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeSystemEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeSystemEventToJson(this);
}

/// System event subtypes.
enum ClaudeSystemSubtype {
  @JsonValue('init')
  init,
  @JsonValue('compact_boundary')
  compactBoundary,
}

/// Context compaction metadata.
@JsonSerializable()
class ClaudeCompactMetadata {
  const ClaudeCompactMetadata({
    this.trigger,
    this.preTokens,
    this.postTokens,
    this.summaryTokens,
  });

  final String? trigger;

  @JsonKey(name: 'pre_tokens')
  final int? preTokens;

  @JsonKey(name: 'post_tokens')
  final int? postTokens;

  @JsonKey(name: 'summary_tokens')
  final int? summaryTokens;

  factory ClaudeCompactMetadata.fromJson(Map<String, dynamic> json) =>
      _$ClaudeCompactMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeCompactMetadataToJson(this);
}

/// Raw API streaming delta (--verbose mode only).
@JsonSerializable()
final class ClaudeStreamDeltaEvent extends ClaudeEvent {
  const ClaudeStreamDeltaEvent({
    required this.eventType,
    this.index,
    this.delta,
  });

  @JsonKey(name: 'event_type')
  final String eventType;

  final int? index;
  final Map<String, dynamic>? delta;

  factory ClaudeStreamDeltaEvent.fromJson(Map<String, dynamic> json) =>
      _$ClaudeStreamDeltaEventFromJson(json);

  Map<String, dynamic> toJson() => _$ClaudeStreamDeltaEventToJson(this);
}
