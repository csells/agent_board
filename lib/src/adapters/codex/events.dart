import 'package:json_annotation/json_annotation.dart';

part 'events.g.dart';

/// Base class for all Codex CLI streaming events.
sealed class CodexEvent {
  const CodexEvent();

  /// Parse a JSONL line into a typed event.
  static CodexEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'thread.started' => CodexThreadStartedEvent.fromJson(json),
      'turn.started' => const CodexTurnStartedEvent(),
      'turn.completed' => CodexTurnCompletedEvent.fromJson(json),
      'turn.failed' => CodexTurnFailedEvent.fromJson(json),
      'item.started' => CodexItemStartedEvent.fromJson(json),
      'item.updated' => CodexItemUpdatedEvent.fromJson(json),
      'item.completed' => CodexItemCompletedEvent.fromJson(json),
      'error' => CodexErrorEvent.fromJson(json),
      _ => null,
    };
  }
}

/// Thread started event - session initialization.
@JsonSerializable()
final class CodexThreadStartedEvent extends CodexEvent {
  const CodexThreadStartedEvent({
    required this.threadId,
  });

  @JsonKey(name: 'thread_id')
  final String threadId;

  factory CodexThreadStartedEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexThreadStartedEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexThreadStartedEventToJson(this);
}

/// Turn started event - beginning of a new turn.
final class CodexTurnStartedEvent extends CodexEvent {
  const CodexTurnStartedEvent();
}

/// Turn completed event - end of turn with usage stats.
@JsonSerializable()
final class CodexTurnCompletedEvent extends CodexEvent {
  const CodexTurnCompletedEvent({
    this.usage,
  });

  final CodexUsage? usage;

  factory CodexTurnCompletedEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexTurnCompletedEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexTurnCompletedEventToJson(this);
}

/// Token usage statistics.
@JsonSerializable()
class CodexUsage {
  const CodexUsage({
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
  });

  @JsonKey(name: 'input_tokens')
  final int? inputTokens;

  @JsonKey(name: 'cached_input_tokens')
  final int? cachedInputTokens;

  @JsonKey(name: 'output_tokens')
  final int? outputTokens;

  factory CodexUsage.fromJson(Map<String, dynamic> json) =>
      _$CodexUsageFromJson(json);

  Map<String, dynamic> toJson() => _$CodexUsageToJson(this);
}

/// Turn failed event.
@JsonSerializable()
final class CodexTurnFailedEvent extends CodexEvent {
  const CodexTurnFailedEvent({
    this.error,
  });

  final CodexTurnError? error;

  factory CodexTurnFailedEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexTurnFailedEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexTurnFailedEventToJson(this);
}

/// Turn error detail.
@JsonSerializable()
class CodexTurnError {
  const CodexTurnError({
    this.message,
  });

  final String? message;

  factory CodexTurnError.fromJson(Map<String, dynamic> json) =>
      _$CodexTurnErrorFromJson(json);

  Map<String, dynamic> toJson() => _$CodexTurnErrorToJson(this);
}

/// Item started event.
@JsonSerializable()
final class CodexItemStartedEvent extends CodexEvent {
  const CodexItemStartedEvent({
    required this.itemType,
  });

  @JsonKey(name: 'item_type')
  final CodexItemType itemType;

  factory CodexItemStartedEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexItemStartedEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexItemStartedEventToJson(this);
}

/// Item updated event - streaming progress.
@JsonSerializable()
final class CodexItemUpdatedEvent extends CodexEvent {
  const CodexItemUpdatedEvent({
    required this.itemType,
    this.content,
    this.reasoning,
    this.summary,
    this.commandLine,
    this.aggregatedOutput,
    this.changes,
    this.toolName,
    this.toolInput,
    this.toolResult,
    this.query,
    this.results,
    this.items,
    this.errorType,
    this.message,
    this.details,
  });

  @JsonKey(name: 'item_type')
  final CodexItemType itemType;

  // agent_message fields
  final String? content;

  // reasoning fields
  final String? reasoning;
  final String? summary;

  // command_execution fields
  @JsonKey(name: 'command_line')
  final String? commandLine;

  @JsonKey(name: 'aggregated_output')
  final String? aggregatedOutput;

  // file_change fields
  final List<CodexFileChange>? changes;

  // mcp_tool_call fields
  @JsonKey(name: 'tool_name')
  final String? toolName;

  @JsonKey(name: 'tool_input')
  final Map<String, dynamic>? toolInput;

  @JsonKey(name: 'tool_result')
  final String? toolResult;

  // web_search fields
  final String? query;
  final List<CodexSearchResult>? results;

  // todo_list fields
  final List<CodexTodoItem>? items;

  // error fields
  @JsonKey(name: 'error_type')
  final String? errorType;

  // Shared error field
  final String? message;
  final Map<String, dynamic>? details;

  factory CodexItemUpdatedEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexItemUpdatedEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexItemUpdatedEventToJson(this);
}

/// Item completed event.
@JsonSerializable()
final class CodexItemCompletedEvent extends CodexEvent {
  const CodexItemCompletedEvent({
    required this.itemType,
    required this.status,
    this.exitCode,
  });

  @JsonKey(name: 'item_type')
  final CodexItemType itemType;

  final CodexItemStatus status;

  @JsonKey(name: 'exit_code')
  final int? exitCode;

  factory CodexItemCompletedEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexItemCompletedEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexItemCompletedEventToJson(this);
}

/// Session-level error event.
@JsonSerializable()
final class CodexErrorEvent extends CodexEvent {
  const CodexErrorEvent({
    this.message,
  });

  final String? message;

  factory CodexErrorEvent.fromJson(Map<String, dynamic> json) =>
      _$CodexErrorEventFromJson(json);

  Map<String, dynamic> toJson() => _$CodexErrorEventToJson(this);
}

/// Item types.
enum CodexItemType {
  @JsonValue('agent_message')
  agentMessage,
  @JsonValue('reasoning')
  reasoning,
  @JsonValue('command_execution')
  commandExecution,
  @JsonValue('file_change')
  fileChange,
  @JsonValue('mcp_tool_call')
  mcpToolCall,
  @JsonValue('web_search')
  webSearch,
  @JsonValue('todo_list')
  todoList,
  @JsonValue('error')
  error,
}

/// Item status values.
enum CodexItemStatus {
  @JsonValue('success')
  success,
  @JsonValue('failed')
  failed,
  @JsonValue('skipped')
  skipped,
}

/// File change details.
@JsonSerializable()
class CodexFileChange {
  const CodexFileChange({
    this.path,
    this.before,
    this.after,
  });

  final String? path;
  final String? before;
  final String? after;

  factory CodexFileChange.fromJson(Map<String, dynamic> json) =>
      _$CodexFileChangeFromJson(json);

  Map<String, dynamic> toJson() => _$CodexFileChangeToJson(this);
}

/// Search result.
@JsonSerializable()
class CodexSearchResult {
  const CodexSearchResult({
    this.title,
    this.url,
    this.snippet,
  });

  final String? title;
  final String? url;
  final String? snippet;

  factory CodexSearchResult.fromJson(Map<String, dynamic> json) =>
      _$CodexSearchResultFromJson(json);

  Map<String, dynamic> toJson() => _$CodexSearchResultToJson(this);
}

/// Todo item.
@JsonSerializable()
class CodexTodoItem {
  const CodexTodoItem({
    this.id,
    this.task,
    this.status,
  });

  final String? id;
  final String? task;
  final String? status;

  factory CodexTodoItem.fromJson(Map<String, dynamic> json) =>
      _$CodexTodoItemFromJson(json);

  Map<String, dynamic> toJson() => _$CodexTodoItemToJson(this);
}
