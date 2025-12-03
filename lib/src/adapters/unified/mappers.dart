import '../claude/events.dart' as claude;
import '../codex/events.dart' as codex;
import '../gemini/events.dart' as gemini;
import 'events.dart';

/// Maps Claude Code events to unified events.
class ClaudeEventMapper {
  const ClaudeEventMapper();

  /// Convert a Claude event to a unified event.
  ///
  /// Returns null if the event should be filtered out.
  UnifiedEvent? map(claude.ClaudeEvent event) {
    return switch (event) {
      claude.ClaudeInitEvent(:final sessionId, :final cwd, :final model) =>
        UnifiedSessionStartEvent(
          sessionId: sessionId,
          workingDirectory: cwd,
          model: model,
        ),
      claude.ClaudeMessageEvent(:final role, :final content)
          when role == claude.ClaudeMessageRole.assistant =>
        _mapMessageContent(content),
      claude.ClaudeMessageEvent() => null, // Ignore user messages
      claude.ClaudeToolUseEvent(
        :final toolUseId,
        :final name,
        :final input
      ) =>
        UnifiedToolCallEvent(
          toolType: _mapClaudeToolType(name),
          name: name,
          toolCallId: toolUseId,
          input: input,
        ),
      claude.ClaudeToolResultEvent(
        :final toolUseId,
        :final content,
        :final isError
      ) =>
        UnifiedToolResultEvent(
          toolType: UnifiedToolType.other,
          toolCallId: toolUseId,
          output: content,
          isError: isError,
        ),
      claude.ClaudeResultEvent(:final status, :final result) =>
        status == claude.ClaudeResultStatus.success
            ? UnifiedCompleteEvent(result: result)
            : UnifiedErrorEvent(
                message: result ?? 'Unknown error',
              ),
      claude.ClaudeErrorEvent(:final error) => UnifiedErrorEvent(
          code: error?.code,
          message: error?.message ?? 'Unknown error',
        ),
      claude.ClaudeSystemEvent(:final subtype, :final metadata) =>
        UnifiedSystemEvent(
          subtype: _mapClaudeSystemSubtype(subtype),
          metadata: metadata?.toJson(),
        ),
      claude.ClaudeStreamDeltaEvent() => null, // Ignore raw deltas
    };
  }

  UnifiedEvent? _mapMessageContent(List<claude.ClaudeContentBlock> content) {
    final textBlocks = content
        .where((b) => b.type == claude.ClaudeContentBlockType.text)
        .map((b) => b.text ?? '')
        .join();

    if (textBlocks.isNotEmpty) {
      return UnifiedTextEvent(text: textBlocks);
    }
    return null;
  }

  UnifiedToolType _mapClaudeToolType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bash') || lower.contains('command')) {
      return UnifiedToolType.command;
    }
    if (lower.contains('read')) {
      return UnifiedToolType.fileRead;
    }
    if (lower.contains('write') || lower.contains('edit')) {
      return UnifiedToolType.fileWrite;
    }
    if (lower.contains('search') || lower.contains('web')) {
      return UnifiedToolType.webSearch;
    }
    if (lower.startsWith('mcp_')) {
      return UnifiedToolType.mcpTool;
    }
    return UnifiedToolType.other;
  }

  UnifiedSystemSubtype _mapClaudeSystemSubtype(claude.ClaudeSystemSubtype subtype) {
    return switch (subtype) {
      claude.ClaudeSystemSubtype.init => UnifiedSystemSubtype.init,
      claude.ClaudeSystemSubtype.compactBoundary => UnifiedSystemSubtype.compaction,
    };
  }
}

/// Maps Codex CLI events to unified events.
class CodexEventMapper {
  const CodexEventMapper();

  /// Convert a Codex event to a unified event.
  ///
  /// Returns null if the event should be filtered out.
  UnifiedEvent? map(codex.CodexEvent event) {
    return switch (event) {
      codex.CodexThreadStartedEvent(:final threadId) =>
        UnifiedSessionStartEvent(sessionId: threadId),
      codex.CodexTurnStartedEvent() => null, // No equivalent
      codex.CodexTurnCompletedEvent(:final usage) => UnifiedCompleteEvent(
          usage: usage != null
              ? UnifiedUsage(
                  inputTokens: usage.inputTokens,
                  outputTokens: usage.outputTokens,
                  cachedTokens: usage.cachedInputTokens,
                )
              : null,
        ),
      codex.CodexTurnFailedEvent(:final error) => UnifiedErrorEvent(
          message: error?.message ?? 'Turn failed',
        ),
      codex.CodexItemStartedEvent() => null, // Wait for updated
      codex.CodexItemUpdatedEvent() => _mapItemUpdated(event),
      codex.CodexItemCompletedEvent(:final itemType, :final status, :final exitCode) =>
        UnifiedToolResultEvent(
          toolType: _mapCodexItemType(itemType),
          isError: status == codex.CodexItemStatus.failed,
          exitCode: exitCode,
        ),
      codex.CodexErrorEvent(:final message) => UnifiedErrorEvent(
          message: message ?? 'Unknown error',
        ),
    };
  }

  UnifiedEvent? _mapItemUpdated(codex.CodexItemUpdatedEvent event) {
    return switch (event.itemType) {
      codex.CodexItemType.agentMessage => event.content != null
          ? UnifiedTextEvent(text: event.content!, isPartial: true)
          : null,
      codex.CodexItemType.reasoning => event.reasoning != null
          ? UnifiedReasoningEvent(
              reasoning: event.reasoning!,
              summary: event.summary,
            )
          : null,
      codex.CodexItemType.commandExecution => UnifiedToolCallEvent(
          toolType: UnifiedToolType.command,
          name: event.commandLine ?? 'command',
          input: {'command': event.commandLine, 'output': event.aggregatedOutput},
        ),
      codex.CodexItemType.fileChange => event.changes != null
          ? UnifiedFileChangeEvent(
              changes: event.changes!
                  .map((c) => UnifiedFileChange(
                        path: c.path ?? '',
                        before: c.before,
                        after: c.after,
                      ))
                  .toList(),
            )
          : null,
      codex.CodexItemType.mcpToolCall => UnifiedToolCallEvent(
          toolType: UnifiedToolType.mcpTool,
          name: event.toolName ?? 'mcp_tool',
          input: event.toolInput,
        ),
      codex.CodexItemType.webSearch => UnifiedToolCallEvent(
          toolType: UnifiedToolType.webSearch,
          name: 'web_search',
          input: {'query': event.query, 'results': event.results?.length},
        ),
      codex.CodexItemType.todoList => UnifiedSystemEvent(
          subtype: UnifiedSystemSubtype.other,
          metadata: {'items': event.items?.map((i) => i.toJson()).toList()},
        ),
      codex.CodexItemType.error => UnifiedErrorEvent(
          code: event.errorType,
          message: event.message ?? 'Item error',
        ),
    };
  }

  UnifiedToolType _mapCodexItemType(codex.CodexItemType itemType) {
    return switch (itemType) {
      codex.CodexItemType.commandExecution => UnifiedToolType.command,
      codex.CodexItemType.fileChange => UnifiedToolType.fileWrite,
      codex.CodexItemType.mcpToolCall => UnifiedToolType.mcpTool,
      codex.CodexItemType.webSearch => UnifiedToolType.webSearch,
      _ => UnifiedToolType.other,
    };
  }
}

/// Maps Gemini CLI events to unified events.
class GeminiEventMapper {
  const GeminiEventMapper();

  bool _sessionStarted = false;

  /// Convert a Gemini event to a unified event.
  ///
  /// Returns null if the event should be filtered out.
  /// May return a list when we need to emit multiple events.
  List<UnifiedEvent> map(gemini.GeminiEvent event) {
    final events = <UnifiedEvent>[];

    // Emit synthetic session start on first event
    if (!_sessionStarted) {
      _sessionStarted = true;
      events.add(const UnifiedSessionStartEvent());
    }

    final mapped = switch (event) {
      gemini.GeminiContentEvent(:final value) =>
        UnifiedTextEvent(text: value, isPartial: true),
      gemini.GeminiToolCallEvent(:final name, :final args) =>
        UnifiedToolCallEvent(
          toolType: _mapGeminiToolType(name),
          name: name,
          input: args,
        ),
      gemini.GeminiResultEvent(:final status, :final stats, :final error) =>
        status == gemini.GeminiResultStatus.success
            ? UnifiedCompleteEvent(
                usage: stats != null
                    ? UnifiedUsage(
                        inputTokens: stats.inputTokens,
                        outputTokens: stats.outputTokens,
                        totalTokens: stats.totalTokens,
                        cachedTokens: stats.cacheTokens,
                        durationMs: stats.durationMs,
                      )
                    : null,
              )
            : UnifiedErrorEvent(
                code: error?.code?.name,
                message: error?.message ?? 'Unknown error',
              ),
      gemini.GeminiErrorEvent(:final error) => UnifiedErrorEvent(
          code: error?.code?.name,
          message: error?.message ?? 'Unknown error',
        ),
      gemini.GeminiRetryEvent(:final attempt, :final maxAttempts, :final delayMs) =>
        UnifiedSystemEvent(
          subtype: UnifiedSystemSubtype.retry,
          metadata: {
            'attempt': attempt,
            'max_attempts': maxAttempts,
            'delay_ms': delayMs,
          },
        ),
    };

    if (mapped != null) {
      events.add(mapped);
    }

    return events;
  }

  UnifiedToolType _mapGeminiToolType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('shell') ||
        lower.contains('command') ||
        lower.contains('exec')) {
      return UnifiedToolType.command;
    }
    if (lower.contains('read')) {
      return UnifiedToolType.fileRead;
    }
    if (lower.contains('write') || lower.contains('edit')) {
      return UnifiedToolType.fileWrite;
    }
    if (lower.contains('search')) {
      return UnifiedToolType.webSearch;
    }
    return UnifiedToolType.other;
  }

  /// Reset mapper state for a new session.
  void reset() {
    _sessionStarted = false;
  }
}
