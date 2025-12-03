// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodexThreadStartedEvent _$CodexThreadStartedEventFromJson(
        Map<String, dynamic> json) =>
    CodexThreadStartedEvent(
      threadId: json['thread_id'] as String,
    );

Map<String, dynamic> _$CodexThreadStartedEventToJson(
        CodexThreadStartedEvent instance) =>
    <String, dynamic>{
      'thread_id': instance.threadId,
    };

CodexTurnCompletedEvent _$CodexTurnCompletedEventFromJson(
        Map<String, dynamic> json) =>
    CodexTurnCompletedEvent(
      usage: json['usage'] == null
          ? null
          : CodexUsage.fromJson(json['usage'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CodexTurnCompletedEventToJson(
        CodexTurnCompletedEvent instance) =>
    <String, dynamic>{
      'usage': instance.usage?.toJson(),
    };

CodexUsage _$CodexUsageFromJson(Map<String, dynamic> json) => CodexUsage(
      inputTokens: (json['input_tokens'] as num?)?.toInt(),
      cachedInputTokens: (json['cached_input_tokens'] as num?)?.toInt(),
      outputTokens: (json['output_tokens'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CodexUsageToJson(CodexUsage instance) =>
    <String, dynamic>{
      'input_tokens': instance.inputTokens,
      'cached_input_tokens': instance.cachedInputTokens,
      'output_tokens': instance.outputTokens,
    };

CodexTurnFailedEvent _$CodexTurnFailedEventFromJson(
        Map<String, dynamic> json) =>
    CodexTurnFailedEvent(
      error: json['error'] == null
          ? null
          : CodexTurnError.fromJson(json['error'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CodexTurnFailedEventToJson(
        CodexTurnFailedEvent instance) =>
    <String, dynamic>{
      'error': instance.error?.toJson(),
    };

CodexTurnError _$CodexTurnErrorFromJson(Map<String, dynamic> json) =>
    CodexTurnError(
      message: json['message'] as String?,
    );

Map<String, dynamic> _$CodexTurnErrorToJson(CodexTurnError instance) =>
    <String, dynamic>{
      'message': instance.message,
    };

CodexItemStartedEvent _$CodexItemStartedEventFromJson(
        Map<String, dynamic> json) =>
    CodexItemStartedEvent(
      itemType: $enumDecode(_$CodexItemTypeEnumMap, json['item_type']),
    );

Map<String, dynamic> _$CodexItemStartedEventToJson(
        CodexItemStartedEvent instance) =>
    <String, dynamic>{
      'item_type': _$CodexItemTypeEnumMap[instance.itemType]!,
    };

const _$CodexItemTypeEnumMap = {
  CodexItemType.agentMessage: 'agent_message',
  CodexItemType.reasoning: 'reasoning',
  CodexItemType.commandExecution: 'command_execution',
  CodexItemType.fileChange: 'file_change',
  CodexItemType.mcpToolCall: 'mcp_tool_call',
  CodexItemType.webSearch: 'web_search',
  CodexItemType.todoList: 'todo_list',
  CodexItemType.error: 'error',
};

CodexItemUpdatedEvent _$CodexItemUpdatedEventFromJson(
        Map<String, dynamic> json) =>
    CodexItemUpdatedEvent(
      itemType: $enumDecode(_$CodexItemTypeEnumMap, json['item_type']),
      content: json['content'] as String?,
      reasoning: json['reasoning'] as String?,
      summary: json['summary'] as String?,
      commandLine: json['command_line'] as String?,
      aggregatedOutput: json['aggregated_output'] as String?,
      changes: (json['changes'] as List<dynamic>?)
          ?.map((e) => CodexFileChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolName: json['tool_name'] as String?,
      toolInput: json['tool_input'] as Map<String, dynamic>?,
      toolResult: json['tool_result'] as String?,
      query: json['query'] as String?,
      results: (json['results'] as List<dynamic>?)
          ?.map((e) => CodexSearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => CodexTodoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorType: json['error_type'] as String?,
      message: json['message'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CodexItemUpdatedEventToJson(
        CodexItemUpdatedEvent instance) =>
    <String, dynamic>{
      'item_type': _$CodexItemTypeEnumMap[instance.itemType]!,
      'content': instance.content,
      'reasoning': instance.reasoning,
      'summary': instance.summary,
      'command_line': instance.commandLine,
      'aggregated_output': instance.aggregatedOutput,
      'changes': instance.changes?.map((e) => e.toJson()).toList(),
      'tool_name': instance.toolName,
      'tool_input': instance.toolInput,
      'tool_result': instance.toolResult,
      'query': instance.query,
      'results': instance.results?.map((e) => e.toJson()).toList(),
      'items': instance.items?.map((e) => e.toJson()).toList(),
      'error_type': instance.errorType,
      'message': instance.message,
      'details': instance.details,
    };

CodexItemCompletedEvent _$CodexItemCompletedEventFromJson(
        Map<String, dynamic> json) =>
    CodexItemCompletedEvent(
      itemType: $enumDecode(_$CodexItemTypeEnumMap, json['item_type']),
      status: $enumDecode(_$CodexItemStatusEnumMap, json['status']),
      exitCode: (json['exit_code'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CodexItemCompletedEventToJson(
        CodexItemCompletedEvent instance) =>
    <String, dynamic>{
      'item_type': _$CodexItemTypeEnumMap[instance.itemType]!,
      'status': _$CodexItemStatusEnumMap[instance.status]!,
      'exit_code': instance.exitCode,
    };

const _$CodexItemStatusEnumMap = {
  CodexItemStatus.success: 'success',
  CodexItemStatus.failed: 'failed',
  CodexItemStatus.skipped: 'skipped',
};

CodexErrorEvent _$CodexErrorEventFromJson(Map<String, dynamic> json) =>
    CodexErrorEvent(
      message: json['message'] as String?,
    );

Map<String, dynamic> _$CodexErrorEventToJson(CodexErrorEvent instance) =>
    <String, dynamic>{
      'message': instance.message,
    };

CodexFileChange _$CodexFileChangeFromJson(Map<String, dynamic> json) =>
    CodexFileChange(
      path: json['path'] as String?,
      before: json['before'] as String?,
      after: json['after'] as String?,
    );

Map<String, dynamic> _$CodexFileChangeToJson(CodexFileChange instance) =>
    <String, dynamic>{
      'path': instance.path,
      'before': instance.before,
      'after': instance.after,
    };

CodexSearchResult _$CodexSearchResultFromJson(Map<String, dynamic> json) =>
    CodexSearchResult(
      title: json['title'] as String?,
      url: json['url'] as String?,
      snippet: json['snippet'] as String?,
    );

Map<String, dynamic> _$CodexSearchResultToJson(CodexSearchResult instance) =>
    <String, dynamic>{
      'title': instance.title,
      'url': instance.url,
      'snippet': instance.snippet,
    };

CodexTodoItem _$CodexTodoItemFromJson(Map<String, dynamic> json) =>
    CodexTodoItem(
      id: json['id'] as String?,
      task: json['task'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$CodexTodoItemToJson(CodexTodoItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'task': instance.task,
      'status': instance.status,
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
