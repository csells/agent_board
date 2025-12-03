// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClaudeInitEvent _$ClaudeInitEventFromJson(Map<String, dynamic> json) =>
    ClaudeInitEvent(
      sessionId: json['session_id'] as String,
      cwd: json['cwd'] as String?,
      model: json['model'] as String?,
    );

Map<String, dynamic> _$ClaudeInitEventToJson(ClaudeInitEvent instance) =>
    <String, dynamic>{
      'session_id': instance.sessionId,
      'cwd': instance.cwd,
      'model': instance.model,
    };

ClaudeMessageEvent _$ClaudeMessageEventFromJson(Map<String, dynamic> json) =>
    ClaudeMessageEvent(
      role: $enumDecode(_$ClaudeMessageRoleEnumMap, json['role']),
      content: (json['content'] as List<dynamic>)
          .map((e) => ClaudeContentBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ClaudeMessageEventToJson(ClaudeMessageEvent instance) =>
    <String, dynamic>{
      'role': _$ClaudeMessageRoleEnumMap[instance.role]!,
      'content': instance.content.map((e) => e.toJson()).toList(),
    };

const _$ClaudeMessageRoleEnumMap = {
  ClaudeMessageRole.user: 'user',
  ClaudeMessageRole.assistant: 'assistant',
};

ClaudeToolUseEvent _$ClaudeToolUseEventFromJson(Map<String, dynamic> json) =>
    ClaudeToolUseEvent(
      toolUseId: json['tool_use_id'] as String,
      name: json['name'] as String,
      input: json['input'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$ClaudeToolUseEventToJson(ClaudeToolUseEvent instance) =>
    <String, dynamic>{
      'tool_use_id': instance.toolUseId,
      'name': instance.name,
      'input': instance.input,
    };

ClaudeToolResultEvent _$ClaudeToolResultEventFromJson(
        Map<String, dynamic> json) =>
    ClaudeToolResultEvent(
      toolUseId: json['tool_use_id'] as String,
      content: json['content'] as String?,
      isError: json['is_error'] as bool? ?? false,
    );

Map<String, dynamic> _$ClaudeToolResultEventToJson(
        ClaudeToolResultEvent instance) =>
    <String, dynamic>{
      'tool_use_id': instance.toolUseId,
      'content': instance.content,
      'is_error': instance.isError,
    };

ClaudeResultEvent _$ClaudeResultEventFromJson(Map<String, dynamic> json) =>
    ClaudeResultEvent(
      status: $enumDecode(_$ClaudeResultStatusEnumMap, json['status']),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      totalDuration: (json['total_duration'] as num?)?.toInt(),
      result: json['result'] as String?,
    );

Map<String, dynamic> _$ClaudeResultEventToJson(ClaudeResultEvent instance) =>
    <String, dynamic>{
      'status': _$ClaudeResultStatusEnumMap[instance.status]!,
      'total_cost': instance.totalCost,
      'total_duration': instance.totalDuration,
      'result': instance.result,
    };

const _$ClaudeResultStatusEnumMap = {
  ClaudeResultStatus.success: 'success',
  ClaudeResultStatus.error: 'error',
  ClaudeResultStatus.cancelled: 'cancelled',
};

ClaudeErrorEvent _$ClaudeErrorEventFromJson(Map<String, dynamic> json) =>
    ClaudeErrorEvent(
      error: json['error'] == null
          ? null
          : ClaudeErrorDetail.fromJson(json['error'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ClaudeErrorEventToJson(ClaudeErrorEvent instance) =>
    <String, dynamic>{
      'error': instance.error?.toJson(),
    };

ClaudeSystemEvent _$ClaudeSystemEventFromJson(Map<String, dynamic> json) =>
    ClaudeSystemEvent(
      subtype: $enumDecode(_$ClaudeSystemSubtypeEnumMap, json['subtype']),
      metadata: json['metadata'] == null
          ? null
          : ClaudeCompactMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ClaudeSystemEventToJson(ClaudeSystemEvent instance) =>
    <String, dynamic>{
      'subtype': _$ClaudeSystemSubtypeEnumMap[instance.subtype]!,
      'metadata': instance.metadata?.toJson(),
    };

const _$ClaudeSystemSubtypeEnumMap = {
  ClaudeSystemSubtype.init: 'init',
  ClaudeSystemSubtype.compactBoundary: 'compact_boundary',
};

ClaudeStreamDeltaEvent _$ClaudeStreamDeltaEventFromJson(
        Map<String, dynamic> json) =>
    ClaudeStreamDeltaEvent(
      delta: json['delta'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ClaudeStreamDeltaEventToJson(
        ClaudeStreamDeltaEvent instance) =>
    <String, dynamic>{
      'delta': instance.delta,
    };

ClaudeContentBlock _$ClaudeContentBlockFromJson(Map<String, dynamic> json) =>
    ClaudeContentBlock(
      type: $enumDecode(_$ClaudeContentBlockTypeEnumMap, json['type']),
      text: json['text'] as String?,
      toolUseId: json['tool_use_id'] as String?,
      toolName: json['tool_name'] as String?,
    );

Map<String, dynamic> _$ClaudeContentBlockToJson(ClaudeContentBlock instance) =>
    <String, dynamic>{
      'type': _$ClaudeContentBlockTypeEnumMap[instance.type]!,
      'text': instance.text,
      'tool_use_id': instance.toolUseId,
      'tool_name': instance.toolName,
    };

const _$ClaudeContentBlockTypeEnumMap = {
  ClaudeContentBlockType.text: 'text',
  ClaudeContentBlockType.toolUse: 'tool_use',
};

ClaudeErrorDetail _$ClaudeErrorDetailFromJson(Map<String, dynamic> json) =>
    ClaudeErrorDetail(
      code: json['code'] as String?,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$ClaudeErrorDetailToJson(ClaudeErrorDetail instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
    };

ClaudeCompactMetadata _$ClaudeCompactMetadataFromJson(
        Map<String, dynamic> json) =>
    ClaudeCompactMetadata(
      conversationTurns: (json['conversation_turns'] as num?)?.toInt(),
      contextTokens: (json['context_tokens'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ClaudeCompactMetadataToJson(
        ClaudeCompactMetadata instance) =>
    <String, dynamic>{
      'conversation_turns': instance.conversationTurns,
      'context_tokens': instance.contextTokens,
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
