import 'dart:async';

import '../claude/adapter.dart' as claude;
import '../codex/adapter.dart' as codex;
import '../gemini/adapter.dart' as gemini;
import 'events.dart';
import 'mappers.dart';
import 'session.dart';

export 'events.dart';
export 'mappers.dart';
export 'session.dart';

/// Unified CLI agent adapter.
///
/// Provides a single interface for interacting with Claude Code, Codex CLI,
/// or Gemini CLI, abstracting away the differences in their streaming
/// protocols and session management.
///
/// ## Usage
///
/// ```dart
/// final adapter = UnifiedCliAdapter();
///
/// // Start a session with any backend
/// final session = await adapter.startSession(
///   config: UnifiedConfig(
///     backend: UnifiedBackend.claude,
///     workingDirectory: '/path/to/project',
///     autoApprove: true,
///   ),
///   prompt: 'Analyze the codebase',
/// );
///
/// // Consume unified events
/// await for (final event in session.events) {
///   switch (event) {
///     case UnifiedSessionStartEvent(:final sessionId):
///       print('Session: $sessionId');
///     case UnifiedTextEvent(:final text):
///       print(text);
///     case UnifiedToolCallEvent(:final name):
///       print('Tool: $name');
///     case UnifiedCompleteEvent(:final usage):
///       print('Done! Tokens: ${usage?.totalTokens}');
///     case UnifiedErrorEvent(:final message):
///       print('Error: $message');
///     // ... handle other events
///   }
/// }
///
/// // Send follow-up
/// await for (final event in session.sendMessage('Now refactor it')) {
///   // ...
/// }
///
/// await session.close();
/// ```
class UnifiedCliAdapter {
  const UnifiedCliAdapter();

  /// Start a new session with the specified backend.
  Future<UnifiedSession> startSession({
    required UnifiedConfig config,
    required String prompt,
  }) async {
    return switch (config.backend) {
      UnifiedBackend.claude => _startClaudeSession(config, prompt),
      UnifiedBackend.codex => _startCodexSession(config, prompt),
      UnifiedBackend.gemini => _startGeminiSession(config, prompt),
    };
  }

  /// Resume an existing session.
  Future<UnifiedSession> resumeSession({
    required UnifiedConfig config,
    required String sessionId,
    required String prompt,
  }) async {
    return switch (config.backend) {
      UnifiedBackend.claude => _resumeClaudeSession(config, sessionId, prompt),
      UnifiedBackend.codex => _resumeCodexSession(config, sessionId, prompt),
      UnifiedBackend.gemini => _resumeGeminiSession(config, sessionId, prompt),
    };
  }

  Future<UnifiedSession> _startClaudeSession(
    UnifiedConfig config,
    String prompt,
  ) async {
    final adapter = claude.ClaudeCliAdapter(
      defaultConfig: claude.ClaudeConfig(
        executable: config.executable ?? 'claude',
        workingDirectory: config.workingDirectory,
        model: config.model,
        dangerouslySkipPermissions: config.autoApprove,
        environment: config.environment,
      ),
    );

    final session = await adapter.startSession(prompt: prompt);
    return _ClaudeUnifiedSession(session);
  }

  Future<UnifiedSession> _resumeClaudeSession(
    UnifiedConfig config,
    String sessionId,
    String prompt,
  ) async {
    final adapter = claude.ClaudeCliAdapter(
      defaultConfig: claude.ClaudeConfig(
        executable: config.executable ?? 'claude',
        workingDirectory: config.workingDirectory,
        model: config.model,
        dangerouslySkipPermissions: config.autoApprove,
        environment: config.environment,
      ),
    );

    final session = await adapter.resumeSession(
      sessionId: sessionId,
      prompt: prompt,
    );
    return _ClaudeUnifiedSession(session);
  }

  Future<UnifiedSession> _startCodexSession(
    UnifiedConfig config,
    String prompt,
  ) async {
    final adapter = codex.CodexCliAdapter(
      defaultConfig: codex.CodexConfig(
        executable: config.executable ?? 'codex',
        workingDirectory: config.workingDirectory,
        model: config.model,
        fullAuto: config.autoApprove,
        environment: config.environment,
      ),
    );

    final (session, events) = await adapter.startSession(prompt: prompt);
    return _CodexUnifiedSession(session, events);
  }

  Future<UnifiedSession> _resumeCodexSession(
    UnifiedConfig config,
    String sessionId,
    String prompt,
  ) async {
    final adapter = codex.CodexCliAdapter(
      defaultConfig: codex.CodexConfig(
        executable: config.executable ?? 'codex',
        workingDirectory: config.workingDirectory,
        model: config.model,
        fullAuto: config.autoApprove,
        environment: config.environment,
      ),
    );

    final (session, events) = await adapter.resumeSession(
      threadId: sessionId,
      prompt: prompt,
    );
    return _CodexUnifiedSession(session, events);
  }

  Future<UnifiedSession> _startGeminiSession(
    UnifiedConfig config,
    String prompt,
  ) async {
    final adapter = gemini.GeminiCliAdapter(
      defaultConfig: gemini.GeminiConfig(
        executable: config.executable ?? 'gemini',
        workingDirectory: config.workingDirectory,
        model: config.model,
        yolo: config.autoApprove,
        environment: config.environment,
      ),
    );

    final (session, events) = await adapter.startSession(prompt: prompt);
    return _GeminiUnifiedSession(session, events);
  }

  Future<UnifiedSession> _resumeGeminiSession(
    UnifiedConfig config,
    String sessionId,
    String prompt,
  ) async {
    final adapter = gemini.GeminiCliAdapter(
      defaultConfig: gemini.GeminiConfig(
        executable: config.executable ?? 'gemini',
        workingDirectory: config.workingDirectory,
        model: config.model,
        yolo: config.autoApprove,
        environment: config.environment,
      ),
    );

    final (session, events) = await adapter.resumeSession(
      sessionId: sessionId,
      prompt: prompt,
    );
    return _GeminiUnifiedSession(session, events);
  }
}

/// Claude Code unified session wrapper.
class _ClaudeUnifiedSession implements UnifiedSession {
  _ClaudeUnifiedSession(this._session);

  final claude.ClaudeSession _session;
  final _mapper = const ClaudeEventMapper();
  late final StreamController<UnifiedEvent> _controller;
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    _controller = StreamController<UnifiedEvent>.broadcast();

    _session.events.listen(
      (event) {
        final mapped = _mapper.map(event);
        if (mapped != null) {
          _controller.add(mapped);
        }
      },
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  @override
  String? get sessionId => _session.sessionId;

  @override
  UnifiedBackend get backend => UnifiedBackend.claude;

  @override
  bool get isClosed => _session.isClosed;

  @override
  Stream<UnifiedEvent> get events {
    _ensureInitialized();
    return _controller.stream;
  }

  @override
  Stream<UnifiedEvent> sendMessage(String message) async* {
    await _session.sendMessage(message);
    // Events come through the main stream for Claude
    yield* events;
  }

  @override
  Future<int> close() => _session.close();

  @override
  Future<void> cancel() => _session.cancel();
}

/// Codex CLI unified session wrapper.
class _CodexUnifiedSession implements UnifiedSession {
  _CodexUnifiedSession(this._session, this._initialEvents);

  final codex.CodexSession _session;
  Stream<codex.CodexEvent> _initialEvents;
  final _mapper = const CodexEventMapper();

  @override
  String? get sessionId => _session.threadId;

  @override
  UnifiedBackend get backend => UnifiedBackend.codex;

  @override
  bool get isClosed => _session.isClosed;

  @override
  Stream<UnifiedEvent> get events async* {
    await for (final event in _initialEvents) {
      final mapped = _mapper.map(event);
      if (mapped != null) {
        yield mapped;
      }
    }
  }

  @override
  Stream<UnifiedEvent> sendMessage(String message) async* {
    final nativeEvents = _session.sendMessage(message);
    _initialEvents = nativeEvents; // Update for next call to events

    await for (final event in nativeEvents) {
      final mapped = _mapper.map(event);
      if (mapped != null) {
        yield mapped;
      }
    }
  }

  @override
  Future<int> close() async {
    _session.close();
    return 0;
  }

  @override
  Future<void> cancel() async {
    _session.close();
  }
}

/// Gemini CLI unified session wrapper.
class _GeminiUnifiedSession implements UnifiedSession {
  _GeminiUnifiedSession(this._session, this._initialEvents);

  final gemini.GeminiSession _session;
  Stream<gemini.GeminiEvent> _initialEvents;
  final _mapper = GeminiEventMapper();

  @override
  String? get sessionId => _session.sessionId;

  @override
  UnifiedBackend get backend => UnifiedBackend.gemini;

  @override
  bool get isClosed => _session.isClosed;

  @override
  Stream<UnifiedEvent> get events async* {
    await for (final event in _initialEvents) {
      final mappedEvents = _mapper.map(event);
      for (final mapped in mappedEvents) {
        yield mapped;
      }
    }
  }

  @override
  Stream<UnifiedEvent> sendMessage(String message) async* {
    _mapper.reset(); // Reset for new turn
    final nativeEvents = _session.sendMessage(message);
    _initialEvents = nativeEvents; // Update for next call to events

    await for (final event in nativeEvents) {
      final mappedEvents = _mapper.map(event);
      for (final mapped in mappedEvents) {
        yield mapped;
      }
    }
  }

  @override
  Future<int> close() async {
    _session.close();
    return 0;
  }

  @override
  Future<void> cancel() async {
    _session.close();
  }
}
