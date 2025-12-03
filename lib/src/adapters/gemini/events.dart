import 'package:json_annotation/json_annotation.dart';

part 'events.g.dart';

/// Base class for all Gemini CLI streaming events.
sealed class GeminiEvent {
  const GeminiEvent();

  /// Parse a JSONL line into a typed event.
  static GeminiEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'content' => GeminiContentEvent.fromJson(json),
      'tool_call' => GeminiToolCallEvent.fromJson(json),
      'result' => GeminiResultEvent.fromJson(json),
      'error' => GeminiErrorEvent.fromJson(json),
      'retry' => GeminiRetryEvent.fromJson(json),
      _ => null,
    };
  }
}

/// Content event - streaming text from the model.
@JsonSerializable()
final class GeminiContentEvent extends GeminiEvent {
  const GeminiContentEvent({
    required this.value,
  });

  /// The text content chunk.
  final String value;

  factory GeminiContentEvent.fromJson(Map<String, dynamic> json) =>
      _$GeminiContentEventFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiContentEventToJson(this);
}

/// Tool call event - tool invocation (atomic, not streamed).
@JsonSerializable()
final class GeminiToolCallEvent extends GeminiEvent {
  const GeminiToolCallEvent({
    required this.name,
    this.args,
  });

  /// Tool name.
  final String name;

  /// Tool arguments.
  final Map<String, dynamic>? args;

  factory GeminiToolCallEvent.fromJson(Map<String, dynamic> json) =>
      _$GeminiToolCallEventFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiToolCallEventToJson(this);
}

/// Result event - session completion with stats.
@JsonSerializable()
final class GeminiResultEvent extends GeminiEvent {
  const GeminiResultEvent({
    required this.status,
    this.stats,
    this.error,
    this.timestamp,
  });

  /// Result status.
  final GeminiResultStatus status;

  /// Token usage statistics (null on error).
  final GeminiStats? stats;

  /// Error details (present if status is error).
  final GeminiErrorDetail? error;

  /// Completion timestamp.
  final String? timestamp;

  factory GeminiResultEvent.fromJson(Map<String, dynamic> json) =>
      _$GeminiResultEventFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiResultEventToJson(this);
}

/// Error event - error during processing.
@JsonSerializable()
final class GeminiErrorEvent extends GeminiEvent {
  const GeminiErrorEvent({
    this.status,
    this.error,
  });

  /// Error status (typically 'error').
  final String? status;

  /// Error details.
  final GeminiErrorDetail? error;

  factory GeminiErrorEvent.fromJson(Map<String, dynamic> json) =>
      _$GeminiErrorEventFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiErrorEventToJson(this);
}

/// Retry event - retry signal on transient failure.
@JsonSerializable()
final class GeminiRetryEvent extends GeminiEvent {
  const GeminiRetryEvent({
    this.attempt,
    this.maxAttempts,
    this.delayMs,
  });

  /// Current retry attempt number.
  final int? attempt;

  /// Maximum retry attempts.
  @JsonKey(name: 'max_attempts')
  final int? maxAttempts;

  /// Delay before next attempt in milliseconds.
  @JsonKey(name: 'delay_ms')
  final int? delayMs;

  factory GeminiRetryEvent.fromJson(Map<String, dynamic> json) =>
      _$GeminiRetryEventFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiRetryEventToJson(this);
}

/// Token usage statistics.
@JsonSerializable()
class GeminiStats {
  const GeminiStats({
    this.totalTokens,
    this.inputTokens,
    this.outputTokens,
    this.thoughtTokens,
    this.cacheTokens,
    this.toolTokens,
    this.durationMs,
    this.toolCalls,
  });

  @JsonKey(name: 'total_tokens')
  final int? totalTokens;

  @JsonKey(name: 'input_tokens')
  final int? inputTokens;

  @JsonKey(name: 'output_tokens')
  final int? outputTokens;

  @JsonKey(name: 'thought_tokens')
  final int? thoughtTokens;

  @JsonKey(name: 'cache_tokens')
  final int? cacheTokens;

  @JsonKey(name: 'tool_tokens')
  final int? toolTokens;

  @JsonKey(name: 'duration_ms')
  final int? durationMs;

  @JsonKey(name: 'tool_calls')
  final int? toolCalls;

  factory GeminiStats.fromJson(Map<String, dynamic> json) =>
      _$GeminiStatsFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiStatsToJson(this);
}

/// Error detail.
@JsonSerializable()
class GeminiErrorDetail {
  const GeminiErrorDetail({
    this.code,
    this.message,
  });

  /// Error code.
  final GeminiErrorCode? code;

  /// Human-readable error message.
  final String? message;

  factory GeminiErrorDetail.fromJson(Map<String, dynamic> json) =>
      _$GeminiErrorDetailFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiErrorDetailToJson(this);
}

/// Result status values.
enum GeminiResultStatus {
  @JsonValue('success')
  success,
  @JsonValue('error')
  error,
  @JsonValue('cancelled')
  cancelled,
}

/// Error code values.
enum GeminiErrorCode {
  @JsonValue('INVALID_CHUNK')
  invalidChunk,
  @JsonValue('EXECUTION_FAILED')
  executionFailed,
  @JsonValue('TIMEOUT')
  timeout,
  @JsonValue('API_ERROR')
  apiError,
  @JsonValue('RATE_LIMIT')
  rateLimit,
}
