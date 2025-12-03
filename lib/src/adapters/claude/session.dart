import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'events.dart';

/// A continuous Claude Code session.
///
/// Unlike Codex and Gemini, Claude Code supports true continuous JSONL
/// streaming via stdin/stdout. A session maintains a persistent connection
/// to the CLI process.
class ClaudeSession {
  ClaudeSession._({
    required this.config,
    required Process process,
    required this.sessionId,
    required StreamController<ClaudeEvent> eventController,
  })  : _process = process,
        _eventController = eventController;

  /// Configuration for this session.
  final ClaudeConfig config;

  /// Session ID (available after init event).
  final String? sessionId;

  final Process _process;
  final StreamController<ClaudeEvent> _eventController;
  bool _isClosed = false;

  /// Stream of events from the session.
  Stream<ClaudeEvent> get events => _eventController.stream;

  /// Whether the session has been closed.
  bool get isClosed => _isClosed;

  /// Send a user message to continue the conversation.
  ///
  /// This writes a JSONL message to the process stdin.
  Future<void> sendMessage(String message) async {
    if (_isClosed) {
      throw StateError('Session is closed');
    }

    final jsonMessage = jsonEncode({
      'type': 'message',
      'role': 'user',
      'content': [
        {'type': 'text', 'text': message}
      ],
    });

    _process.stdin.writeln(jsonMessage);
    await _process.stdin.flush();
  }

  /// Send a raw JSONL message to the process.
  ///
  /// Use this for advanced use cases where you need to send
  /// custom message types.
  Future<void> sendRaw(Map<String, dynamic> message) async {
    if (_isClosed) {
      throw StateError('Session is closed');
    }

    _process.stdin.writeln(jsonEncode(message));
    await _process.stdin.flush();
  }

  /// Cancel the session by sending SIGTERM to the process.
  Future<void> cancel() async {
    if (_isClosed) return;

    _process.kill(ProcessSignal.sigterm);
    await close();
  }

  /// Close the session gracefully.
  ///
  /// This closes stdin and waits for the process to exit.
  Future<int> close() async {
    if (_isClosed) return _process.exitCode;

    _isClosed = true;
    await _process.stdin.close();
    final exitCode = await _process.exitCode;
    await _eventController.close();
    return exitCode;
  }

  /// Start a new Claude session.
  ///
  /// If [sessionId] is provided, resumes an existing session.
  static Future<ClaudeSession> start({
    required ClaudeConfig config,
    required String initialPrompt,
    String? sessionId,
  }) async {
    final args = config.buildArgs(sessionId: sessionId);

    final process = await Process.start(
      config.executable,
      args,
      workingDirectory: config.workingDirectory,
      environment: config.environment,
    );

    final eventController = StreamController<ClaudeEvent>.broadcast();
    String? detectedSessionId = sessionId;

    // Parse stdout JSONL events
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.trim().isEmpty) return;
        if (!line.trim().startsWith('{')) return;

        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final event = ClaudeEvent.fromJson(json);
          if (event != null) {
            // Capture session ID from init event
            if (event is ClaudeInitEvent) {
              detectedSessionId = event.sessionId;
            }
            eventController.add(event);
          }
        } catch (e) {
          // Ignore malformed JSON lines
        }
      },
      onError: (Object error) {
        eventController.addError(error);
      },
      onDone: () {
        eventController.close();
      },
    );

    // Log stderr for debugging
    process.stderr.transform(utf8.decoder).listen((data) {
      // Could add a debug callback here
    });

    // Send the initial prompt
    final initialMessage = jsonEncode({
      'type': 'message',
      'role': 'user',
      'content': [
        {'type': 'text', 'text': initialPrompt}
      ],
    });
    process.stdin.writeln(initialMessage);
    await process.stdin.flush();

    return ClaudeSession._(
      config: config,
      process: process,
      sessionId: detectedSessionId,
      eventController: eventController,
    );
  }

  /// Resume an existing session.
  static Future<ClaudeSession> resume({
    required ClaudeConfig config,
    required String sessionId,
    required String prompt,
  }) {
    return start(
      config: config,
      initialPrompt: prompt,
      sessionId: sessionId,
    );
  }
}
