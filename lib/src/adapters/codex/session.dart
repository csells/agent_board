import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'events.dart';

/// A Codex CLI session.
///
/// Unlike Claude Code, Codex does not support continuous JSONL streaming.
/// Each message requires spawning a new process. Multi-turn conversations
/// are achieved via the `--resume` flag with a thread ID.
class CodexSession {
  CodexSession._({
    required this.config,
    required this.threadId,
  });

  /// Configuration for this session.
  final CodexConfig config;

  /// Thread ID for session continuity.
  ///
  /// This is obtained from the `thread.started` event and used
  /// with `--resume` for subsequent messages.
  String? threadId;

  bool _isClosed = false;

  /// Whether the session has been closed.
  bool get isClosed => _isClosed;

  /// Send a message and receive streaming events.
  ///
  /// Each call spawns a new codex process. If this is not the first
  /// message, the `--resume` flag is used with the thread ID.
  ///
  /// Returns a stream of events from this turn.
  Stream<CodexEvent> sendMessage(String prompt) async* {
    if (_isClosed) {
      throw StateError('Session is closed');
    }

    final args = config.buildArgs(
      prompt: prompt,
      threadId: threadId,
    );

    final process = await Process.start(
      config.executable,
      args,
      workingDirectory: config.workingDirectory,
      environment: config.environment,
    );

    // Close stdin immediately - Codex doesn't read from it
    await process.stdin.close();

    // Parse JSONL from stdout
    await for (final line in process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      if (!line.trim().startsWith('{')) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final event = CodexEvent.fromJson(json);
        if (event != null) {
          // Capture thread ID from first event
          if (event is CodexThreadStartedEvent) {
            threadId = event.threadId;
          }
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
        yield CodexErrorEvent(message: stderr.trim());
      }
    }
  }

  /// Close the session.
  ///
  /// This is a no-op for Codex since each message uses a fresh process,
  /// but it marks the session as closed to prevent further use.
  void close() {
    _isClosed = true;
  }

  /// Start a new Codex session.
  ///
  /// The [initialPrompt] is sent as the first message. The returned
  /// session can be used for follow-up messages via [sendMessage].
  static Future<(CodexSession, Stream<CodexEvent>)> start({
    required CodexConfig config,
    required String initialPrompt,
  }) async {
    final session = CodexSession._(
      config: config,
      threadId: null,
    );

    final events = session.sendMessage(initialPrompt);
    return (session, events);
  }

  /// Resume an existing session by thread ID.
  ///
  /// The [prompt] is sent as the continuation message.
  static Future<(CodexSession, Stream<CodexEvent>)> resume({
    required CodexConfig config,
    required String threadId,
    required String prompt,
  }) async {
    final session = CodexSession._(
      config: config,
      threadId: threadId,
    );

    final events = session.sendMessage(prompt);
    return (session, events);
  }
}
