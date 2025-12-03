// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeminiContentEvent _$GeminiContentEventFromJson(Map<String, dynamic> json) =>
    GeminiContentEvent(
      value: json['value'] as String,
    );

Map<String, dynamic> _$GeminiContentEventToJson(GeminiContentEvent instance) =>
    <String, dynamic>{
      'value': instance.value,
    };

GeminiToolCallEvent _$GeminiToolCallEventFromJson(Map<String, dynamic> json) =>
    GeminiToolCallEvent(
      name: json['name'] as String,
      args: json['args'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$GeminiToolCallEventToJson(
        GeminiToolCallEvent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'args': instance.args,
    };

GeminiResultEvent _$GeminiResultEventFromJson(Map<String, dynamic> json) =>
    GeminiResultEvent(
      status: $enumDecode(_$GeminiResultStatusEnumMap, json['status']),
      stats: json['stats'] == null
          ? null
          : GeminiStats.fromJson(json['stats'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : GeminiErrorDetail.fromJson(json['error'] as Map<String, dynamic>),
      timestamp: json['timestamp'] as String?,
    );

Map<String, dynamic> _$GeminiResultEventToJson(GeminiResultEvent instance) =>
    <String, dynamic>{
      'status': _$GeminiResultStatusEnumMap[instance.status]!,
      'stats': instance.stats?.toJson(),
      'error': instance.error?.toJson(),
      'timestamp': instance.timestamp,
    };

const _$GeminiResultStatusEnumMap = {
  GeminiResultStatus.success: 'success',
  GeminiResultStatus.error: 'error',
  GeminiResultStatus.cancelled: 'cancelled',
};

GeminiErrorEvent _$GeminiErrorEventFromJson(Map<String, dynamic> json) =>
    GeminiErrorEvent(
      status: json['status'] as String?,
      error: json['error'] == null
          ? null
          : GeminiErrorDetail.fromJson(json['error'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GeminiErrorEventToJson(GeminiErrorEvent instance) =>
    <String, dynamic>{
      'status': instance.status,
      'error': instance.error?.toJson(),
    };

GeminiRetryEvent _$GeminiRetryEventFromJson(Map<String, dynamic> json) =>
    GeminiRetryEvent(
      attempt: (json['attempt'] as num?)?.toInt(),
      maxAttempts: (json['max_attempts'] as num?)?.toInt(),
      delayMs: (json['delay_ms'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GeminiRetryEventToJson(GeminiRetryEvent instance) =>
    <String, dynamic>{
      'attempt': instance.attempt,
      'max_attempts': instance.maxAttempts,
      'delay_ms': instance.delayMs,
    };

GeminiStats _$GeminiStatsFromJson(Map<String, dynamic> json) => GeminiStats(
      totalTokens: (json['total_tokens'] as num?)?.toInt(),
      inputTokens: (json['input_tokens'] as num?)?.toInt(),
      outputTokens: (json['output_tokens'] as num?)?.toInt(),
      thoughtTokens: (json['thought_tokens'] as num?)?.toInt(),
      cacheTokens: (json['cache_tokens'] as num?)?.toInt(),
      toolTokens: (json['tool_tokens'] as num?)?.toInt(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      toolCalls: (json['tool_calls'] as num?)?.toInt(),
    );

Map<String, dynamic> _$GeminiStatsToJson(GeminiStats instance) =>
    <String, dynamic>{
      'total_tokens': instance.totalTokens,
      'input_tokens': instance.inputTokens,
      'output_tokens': instance.outputTokens,
      'thought_tokens': instance.thoughtTokens,
      'cache_tokens': instance.cacheTokens,
      'tool_tokens': instance.toolTokens,
      'duration_ms': instance.durationMs,
      'tool_calls': instance.toolCalls,
    };

GeminiErrorDetail _$GeminiErrorDetailFromJson(Map<String, dynamic> json) =>
    GeminiErrorDetail(
      code: $enumDecodeNullable(_$GeminiErrorCodeEnumMap, json['code']),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$GeminiErrorDetailToJson(GeminiErrorDetail instance) =>
    <String, dynamic>{
      'code': _$GeminiErrorCodeEnumMap[instance.code],
      'message': instance.message,
    };

const _$GeminiErrorCodeEnumMap = {
  GeminiErrorCode.invalidChunk: 'INVALID_CHUNK',
  GeminiErrorCode.executionFailed: 'EXECUTION_FAILED',
  GeminiErrorCode.timeout: 'TIMEOUT',
  GeminiErrorCode.apiError: 'API_ERROR',
  GeminiErrorCode.rateLimit: 'RATE_LIMIT',
};

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  Object? source, {
  T? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

T? $enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  Object? source, {
  T? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}
