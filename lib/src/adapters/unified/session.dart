import 'dart:async';

import 'events.dart';

/// Abstract interface for a unified CLI agent session.
///
/// Provides a common API for interacting with Claude Code, Codex CLI,
/// or Gemini CLI sessions without knowing the underlying backend.
abstract interface class UnifiedSession {
  /// Session identifier for resumption.
  ///
  /// May be null until the first event is received.
  String? get sessionId;

  /// The backend type for this session.
  UnifiedBackend get backend;

  /// Whether the session has been closed.
  bool get isClosed;

  /// Stream of unified events from the session.
  ///
  /// For backends with continuous streaming (Claude), this stream
  /// continues across multiple messages.
  ///
  /// For backends with process-per-turn (Codex, Gemini), this stream
  /// is for the current turn only. Call [sendMessage] to get a new
  /// stream for the next turn.
  Stream<UnifiedEvent> get events;

  /// Send a follow-up message.
  ///
  /// For continuous backends (Claude), this writes to the existing
  /// process stdin.
  ///
  /// For process-per-turn backends (Codex, Gemini), this spawns a
  /// new process with the session ID for resumption.
  ///
  /// Returns a stream of events for this message/turn.
  Stream<UnifiedEvent> sendMessage(String message);

  /// Close the session gracefully.
  ///
  /// Returns the exit code of the underlying process(es).
  Future<int> close();

  /// Cancel the session immediately.
  Future<void> cancel();
}

/// Backend types.
enum UnifiedBackend {
  /// Claude Code CLI.
  claude,

  /// Codex CLI (OpenAI).
  codex,

  /// Gemini CLI (Google).
  gemini,
}

/// Configuration for creating a unified session.
class UnifiedConfig {
  const UnifiedConfig({
    required this.backend,
    this.executable,
    this.workingDirectory,
    this.model,
    this.autoApprove = false,
    this.environment,
  });

  /// Which CLI backend to use.
  final UnifiedBackend backend;

  /// Path to the CLI executable (uses default if null).
  final String? executable;

  /// Working directory for the session.
  final String? workingDirectory;

  /// Model to use.
  final String? model;

  /// Auto-approve all tool executions.
  ///
  /// Maps to:
  /// - Claude: `dangerouslySkipPermissions`
  /// - Codex: `fullAuto`
  /// - Gemini: `yolo`
  final bool autoApprove;

  /// Additional environment variables.
  final Map<String, String>? environment;
}
