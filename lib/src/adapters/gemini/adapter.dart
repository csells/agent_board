import 'dart:async';

import 'config.dart';
import 'events.dart';
import 'session.dart';

export 'config.dart';
export 'events.dart';
export 'session.dart';

/// Gemini CLI adapter.
///
/// Provides a Dart interface to the Gemini CLI with full support for:
/// - JSONL streaming output via `--output-format stream-json`
/// - Multi-turn conversations via `--resume`
/// - Session resumption by ID or index
///
/// ## Usage
///
/// ```dart
/// final adapter = GeminiCliAdapter();
///
/// // Start a new session
/// final (session, events) = await adapter.startSession(
///   config: GeminiConfig(
///     workingDirectory: '/path/to/project',
///     yolo: true,
///   ),
///   prompt: 'Analyze the codebase structure',
/// );
///
/// // Listen to events from the first turn
/// await for (final event in events) {
///   switch (event) {
///     case GeminiContentEvent(:final value):
///       print(value);
///     case GeminiToolCallEvent(:final name, :final args):
///       print('Tool: $name');
///     case GeminiResultEvent(:final status, :final stats):
///       print('Status: $status, Tokens: ${stats?.totalTokens}');
///     case GeminiErrorEvent(:final error):
///       print('Error: ${error?.message}');
///     case GeminiRetryEvent(:final attempt):
///       print('Retrying: attempt $attempt');
///   }
/// }
///
/// // Send follow-up message (spawns new process with --resume)
/// // Note: Obtain session ID from `gemini --list-sessions`
/// session.sessionId = 'session-uuid-here';
/// await for (final event in session.sendMessage('Now refactor the auth module')) {
///   // Handle events...
/// }
///
/// // Close when done
/// session.close();
/// ```
class GeminiCliAdapter {
  const GeminiCliAdapter({
    this.defaultConfig = const GeminiConfig(),
  });

  /// Default configuration for new sessions.
  final GeminiConfig defaultConfig;

  /// Start a new Gemini session.
  ///
  /// The [prompt] is sent as the initial message.
  /// The [config] overrides [defaultConfig] for this session.
  ///
  /// Returns a tuple of (session, event stream for first turn).
  Future<(GeminiSession, Stream<GeminiEvent>)> startSession({
    required String prompt,
    GeminiConfig? config,
  }) {
    final effectiveConfig = config ?? defaultConfig;
    return GeminiSession.start(
      config: effectiveConfig,
      initialPrompt: prompt,
    );
  }

  /// Resume an existing session by session ID.
  ///
  /// The session ID can be a UUID or a numeric index.
  /// The [prompt] is sent as the continuation message.
  ///
  /// Returns a tuple of (session, event stream for this turn).
  Future<(GeminiSession, Stream<GeminiEvent>)> resumeSession({
    required String sessionId,
    required String prompt,
    GeminiConfig? config,
  }) {
    final effectiveConfig = config ?? defaultConfig;
    return GeminiSession.resume(
      config: effectiveConfig,
      sessionId: sessionId,
      prompt: prompt,
    );
  }
}
