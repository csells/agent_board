import 'dart:async';

import 'config.dart';
import 'events.dart';
import 'session.dart';

export 'config.dart';
export 'events.dart';
export 'session.dart';

/// Codex CLI adapter.
///
/// Provides a Dart interface to the Codex CLI with full support for:
/// - JSONL streaming output via `--output-jsonl`
/// - Multi-turn conversations via `--resume`
/// - Session resumption
///
/// ## Usage
///
/// ```dart
/// final adapter = CodexCliAdapter();
///
/// // Start a new session
/// final (session, events) = await adapter.startSession(
///   config: CodexConfig(
///     workingDirectory: '/path/to/project',
///     fullAuto: true,
///   ),
///   prompt: 'Analyze the codebase structure',
/// );
///
/// // Listen to events from the first turn
/// await for (final event in events) {
///   switch (event) {
///     case CodexThreadStartedEvent(:final threadId):
///       print('Thread: $threadId');
///     case CodexItemUpdatedEvent(:final itemType, :final content):
///       if (itemType == CodexItemType.agentMessage && content != null) {
///         print(content);
///       }
///     case CodexTurnCompletedEvent(:final usage):
///       print('Tokens: ${usage?.inputTokens}/${usage?.outputTokens}');
///     // ... handle other events
///   }
/// }
///
/// // Send follow-up message (spawns new process with --resume)
/// await for (final event in session.sendMessage('Now refactor the auth module')) {
///   // Handle events...
/// }
///
/// // Close when done
/// session.close();
/// ```
class CodexCliAdapter {
  const CodexCliAdapter({
    this.defaultConfig = const CodexConfig(),
  });

  /// Default configuration for new sessions.
  final CodexConfig defaultConfig;

  /// Start a new Codex session.
  ///
  /// The [prompt] is sent as the initial message.
  /// The [config] overrides [defaultConfig] for this session.
  ///
  /// Returns a tuple of (session, event stream for first turn).
  Future<(CodexSession, Stream<CodexEvent>)> startSession({
    required String prompt,
    CodexConfig? config,
  }) {
    final effectiveConfig = config ?? defaultConfig;
    return CodexSession.start(
      config: effectiveConfig,
      initialPrompt: prompt,
    );
  }

  /// Resume an existing session by thread ID.
  ///
  /// The [prompt] is sent as the continuation message.
  ///
  /// Returns a tuple of (session, event stream for this turn).
  Future<(CodexSession, Stream<CodexEvent>)> resumeSession({
    required String threadId,
    required String prompt,
    CodexConfig? config,
  }) {
    final effectiveConfig = config ?? defaultConfig;
    return CodexSession.resume(
      config: effectiveConfig,
      threadId: threadId,
      prompt: prompt,
    );
  }
}
