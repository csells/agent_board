/// Unified event types that abstract over Claude Code, Codex CLI, and Gemini CLI.
///
/// These events provide a common interface for consuming streaming output
/// from any of the three CLI agents without knowing the underlying backend.
library;

/// Base class for all unified streaming events.
sealed class UnifiedEvent {
  const UnifiedEvent();
}

/// Session initialized - emitted when the CLI process starts.
///
/// Maps from:
/// - Claude: `init` event
/// - Codex: `thread.started` event
/// - Gemini: First event (implicit, no explicit init)
final class UnifiedSessionStartEvent extends UnifiedEvent {
  const UnifiedSessionStartEvent({
    this.sessionId,
    this.workingDirectory,
    this.model,
  });

  /// Session identifier for resumption.
  final String? sessionId;

  /// Working directory of the session.
  final String? workingDirectory;

  /// Model being used.
  final String? model;
}

/// Text content from the model (streaming).
///
/// Maps from:
/// - Claude: `message` event with text content blocks
/// - Codex: `item.updated` with `item_type: agent_message`
/// - Gemini: `content` event
final class UnifiedTextEvent extends UnifiedEvent {
  const UnifiedTextEvent({
    required this.text,
    this.isPartial = false,
  });

  /// The text content.
  final String text;

  /// Whether this is a partial/streaming chunk.
  final bool isPartial;
}

/// Reasoning/thinking from the model.
///
/// Maps from:
/// - Claude: Not directly exposed (internal)
/// - Codex: `item.updated` with `item_type: reasoning`
/// - Gemini: Not directly exposed
final class UnifiedReasoningEvent extends UnifiedEvent {
  const UnifiedReasoningEvent({
    required this.reasoning,
    this.summary,
  });

  /// The reasoning content.
  final String reasoning;

  /// Optional summary of the reasoning.
  final String? summary;
}

/// Tool invocation started.
///
/// Maps from:
/// - Claude: `tool_use` event
/// - Codex: `item.started` + `item.updated` for tool-like items
/// - Gemini: `tool_call` event
final class UnifiedToolCallEvent extends UnifiedEvent {
  const UnifiedToolCallEvent({
    required this.toolType,
    required this.name,
    this.toolCallId,
    this.input,
  });

  /// Type of tool being called.
  final UnifiedToolType toolType;

  /// Tool name or command.
  final String name;

  /// Unique identifier for this tool call (for matching results).
  final String? toolCallId;

  /// Input arguments.
  final Map<String, dynamic>? input;
}

/// Tool execution result.
///
/// Maps from:
/// - Claude: `tool_result` event
/// - Codex: `item.completed` event
/// - Gemini: Implicit (tool results not streamed separately)
final class UnifiedToolResultEvent extends UnifiedEvent {
  const UnifiedToolResultEvent({
    required this.toolType,
    this.toolCallId,
    this.output,
    this.isError = false,
    this.exitCode,
  });

  /// Type of tool that was executed.
  final UnifiedToolType toolType;

  /// Matching tool call ID.
  final String? toolCallId;

  /// Output from the tool execution.
  final String? output;

  /// Whether the tool execution resulted in an error.
  final bool isError;

  /// Exit code for command executions.
  final int? exitCode;
}

/// File change event.
///
/// Maps from:
/// - Claude: `tool_use`/`tool_result` for Edit/Write tools
/// - Codex: `item.updated` with `item_type: file_change`
/// - Gemini: `tool_call` for write_file
final class UnifiedFileChangeEvent extends UnifiedEvent {
  const UnifiedFileChangeEvent({
    required this.changes,
  });

  /// List of file changes.
  final List<UnifiedFileChange> changes;
}

/// Individual file change.
class UnifiedFileChange {
  const UnifiedFileChange({
    required this.path,
    this.before,
    this.after,
    this.operation,
  });

  /// File path.
  final String path;

  /// Content before the change.
  final String? before;

  /// Content after the change.
  final String? after;

  /// Type of operation (create, modify, delete).
  final UnifiedFileOperation? operation;
}

/// File operation type.
enum UnifiedFileOperation {
  create,
  modify,
  delete,
}

/// Session/turn completed successfully.
///
/// Maps from:
/// - Claude: `result` event with status: success
/// - Codex: `turn.completed` event
/// - Gemini: `result` event with status: success
final class UnifiedCompleteEvent extends UnifiedEvent {
  const UnifiedCompleteEvent({
    this.usage,
    this.result,
  });

  /// Token usage statistics.
  final UnifiedUsage? usage;

  /// Final result text (for structured output).
  final String? result;
}

/// Error event.
///
/// Maps from:
/// - Claude: `error` event or `result` with status: error
/// - Codex: `turn.failed` or `error` event
/// - Gemini: `error` event or `result` with status: error
final class UnifiedErrorEvent extends UnifiedEvent {
  const UnifiedErrorEvent({
    this.code,
    required this.message,
    this.isRecoverable = false,
  });

  /// Error code.
  final String? code;

  /// Error message.
  final String message;

  /// Whether the error is recoverable (e.g., retry).
  final bool isRecoverable;
}

/// System/internal event.
///
/// Maps from:
/// - Claude: `system` event
/// - Codex: Various internal events
/// - Gemini: `retry` event
final class UnifiedSystemEvent extends UnifiedEvent {
  const UnifiedSystemEvent({
    required this.subtype,
    this.metadata,
  });

  /// System event subtype.
  final UnifiedSystemSubtype subtype;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;
}

/// Token usage statistics.
class UnifiedUsage {
  const UnifiedUsage({
    this.inputTokens,
    this.outputTokens,
    this.cachedTokens,
    this.totalTokens,
    this.durationMs,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? cachedTokens;
  final int? totalTokens;
  final int? durationMs;
}

/// Unified tool types that map across all CLIs.
enum UnifiedToolType {
  /// Shell command execution.
  command,

  /// File read operation.
  fileRead,

  /// File write/edit operation.
  fileWrite,

  /// Web search.
  webSearch,

  /// MCP tool call.
  mcpTool,

  /// Other/unknown tool.
  other,
}

/// System event subtypes.
enum UnifiedSystemSubtype {
  /// Initialization info.
  init,

  /// Context compaction occurred.
  compaction,

  /// Retry in progress.
  retry,

  /// Other system event.
  other,
}
