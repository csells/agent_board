import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'events.dart';

/// A Gemini CLI session.
///
/// Unlike Claude Code, Gemini does not support continuous JSONL streaming.
/// Each message requires spawning a new process. Multi-turn conversations
/// are achieved via the `--resume` flag with a session ID.
class GeminiSession {
  GeminiSession._({
    required this.config,
    required this.sessionId,
  });

  /// Configuration for this session.
  final GeminiConfig config;

  /// Session ID for session continuity.
  ///
  /// Gemini sessions are identified by UUID or numeric index.
  /// This is passed to `--resume` for subsequent messages.
  String? sessionId;

  bool _isClosed = false;

  /// Whether the session has been closed.
  bool get isClosed => _isClosed;

  /// Send a message and receive streaming events.
  ///
  /// Each call spawns a new gemini process. If this is not the first
  /// message, the `--resume` flag is used with the session ID.
  ///
  /// Returns a stream of events from this turn.
  Stream<GeminiEvent> sendMessage(String prompt) async* {
    if (_isClosed) {
      throw StateError('Session is closed');
    }

    final args = config.buildArgs(
      prompt: prompt,
      sessionId: sessionId,
    );

    final process = await Process.start(
      config.executable,
      args,
      workingDirectory: config.workingDirectory,
      environment: config.environment,
    );

    // Close stdin immediately - Gemini doesn't read JSONL from it
    await process.stdin.close();

    // Parse JSONL from stdout
    await for (final line in process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      if (!line.trim().startsWith('{')) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final event = GeminiEvent.fromJson(json);
        if (event != null) {
          yield event;
        }
      } catch (e) {
        // Ignore malformed JSON lines
      }
    }

    // Wait for process to exit
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      // Process exited with error - stderr may have details
      final stderr = await process.stderr.transform(utf8.decoder).join();
      if (stderr.isNotEmpty) {
        yield GeminiErrorEvent(
          status: 'error',
          error: GeminiErrorDetail(
            code: GeminiErrorCode.executionFailed,
            message: stderr.trim(),
          ),
        );
      }
    }
  }

  /// Close the session.
  ///
  /// This is a no-op for Gemini since each message uses a fresh process,
  /// but it marks the session as closed to prevent further use.
  void close() {
    _isClosed = true;
  }

  /// Start a new Gemini session.
  ///
  /// The [initialPrompt] is sent as the first message. The returned
  /// session can be used for follow-up messages via [sendMessage].
  ///
  /// Note: Unlike Codex, Gemini doesn't emit a session ID in its events.
  /// For resume functionality, the session ID must be obtained from
  /// Gemini's session list (`gemini --list-sessions`).
  static Future<(GeminiSession, Stream<GeminiEvent>)> start({
    required GeminiConfig config,
    required String initialPrompt,
  }) async {
    final session = GeminiSession._(
      config: config,
      sessionId: null,
    );

    final events = session.sendMessage(initialPrompt);
    return (session, events);
  }

  /// Resume an existing session by session ID.
  ///
  /// The session ID can be a UUID or a numeric index.
  /// The [prompt] is sent as the continuation message.
  static Future<(GeminiSession, Stream<GeminiEvent>)> resume({
    required GeminiConfig config,
    required String sessionId,
    required String prompt,
  }) async {
    final session = GeminiSession._(
      config: config,
      sessionId: sessionId,
    );

    final events = session.sendMessage(prompt);
    return (session, events);
  }
}
