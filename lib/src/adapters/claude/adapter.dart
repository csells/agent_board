import 'dart:async';

import 'config.dart';
import 'session.dart';

export 'config.dart';
export 'events.dart';
export 'session.dart';

/// Claude Code CLI adapter.
///
/// Provides a Dart interface to the Claude Code CLI with full support for:
/// - Continuous JSONL streaming via stdin/stdout
/// - Multi-turn conversations within a single process
/// - Session resumption
/// - Permission callback delegation via MCP
///
/// ## Usage
///
/// ```dart
/// final adapter = ClaudeCliAdapter();
///
/// // Start a new session
/// final session = await adapter.startSession(
///   config: ClaudeConfig(
///     workingDirectory: '/path/to/project',
///     dangerouslySkipPermissions: true,
///   ),
///   prompt: 'Analyze the codebase structure',
/// );
///
/// // Listen to events
/// await for (final event in session.events) {
///   switch (event) {
///     case ClaudeInitEvent(:final sessionId):
///       print('Session started: $sessionId');
///     case ClaudeMessageEvent(:final content):
///       for (final block in content) {
///         if (block.type == ClaudeContentBlockType.text) {
///           print(block.text);
///         }
///       }
///     case ClaudeToolUseEvent(:final name, :final input):
///       print('Tool: $name');
///     case ClaudeResultEvent(:final status):
///       print('Completed: $status');
///     // ... handle other events
///   }
/// }
///
/// // Send follow-up message
/// await session.sendMessage('Now refactor the auth module');
///
/// // Close when done
/// await session.close();
/// ```
class ClaudeCliAdapter {
  const ClaudeCliAdapter({
    this.defaultConfig = const ClaudeConfig(),
  });

  /// Default configuration for new sessions.
  final ClaudeConfig defaultConfig;

  /// Start a new Claude Code session.
  ///
  /// The [prompt] is sent as the initial user message.
  /// The [config] overrides [defaultConfig] for this session.
  Future<ClaudeSession> startSession({
    required String prompt,
    ClaudeConfig? config,
  }) {
    final effectiveConfig = config ?? defaultConfig;
    return ClaudeSession.start(
      config: effectiveConfig,
      initialPrompt: prompt,
    );
  }

  /// Resume an existing session by ID.
  ///
  /// The [prompt] is sent as the continuation message.
  Future<ClaudeSession> resumeSession({
    required String sessionId,
    required String prompt,
    ClaudeConfig? config,
  }) {
    final effectiveConfig = config ?? defaultConfig;
    return ClaudeSession.resume(
      config: effectiveConfig,
      sessionId: sessionId,
      prompt: prompt,
    );
  }
}
