import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/models.dart';
import 'middleware/middleware.dart';

/// Main Agent Board service.
///
/// Provides REST API and WebSocket endpoints for managing ACP-based
/// coding agent sessions.
class AgentService {
  final Map<String, Project> _projects;
  final Map<String, Agent> _agents;
  final Map<String, Session> _sessions = {};
  final Map<String, StreamController<SessionEvent>> _eventStreams = {};
  final Map<String, Set<WebSocketChannel>> _wsConnections = {};

  final Uuid _uuid = const Uuid();
  final RateLimiter _rateLimiter;

  /// Maximum prompt length to prevent abuse.
  static const int maxPromptLength = 10000;

  /// Maximum number of concurrent sessions.
  static const int maxConcurrentSessions = 50;

  AgentService({
    Map<String, Project>? projects,
    Map<String, Agent>? agents,
    RateLimiter? rateLimiter,
  })  : _projects = projects ?? _defaultProjects(),
        _agents = agents ?? _defaultAgents(),
        _rateLimiter = rateLimiter ?? RateLimiter();

  static Map<String, Project> _defaultProjects() => {
        'flutter_ai_toolkit': const Project(
          id: 'flutter_ai_toolkit',
          name: 'Flutter AI Toolkit',
          path: '/Users/chris/code/flutter_ai_toolkit',
        ),
        'muse': const Project(
          id: 'muse',
          name: 'Muse Chat',
          path: '/Users/chris/code/muse',
        ),
      };

  static Map<String, Agent> _defaultAgents() => const {
        'claude': Agent(id: 'claude', name: 'Claude Code'),
        'gemini': Agent(id: 'gemini', name: 'Gemini CLI'),
        'codex': Agent(id: 'codex', name: 'Codex'),
      };

  /// Creates the complete HTTP handler with all middleware and routes.
  Handler createHandler() {
    final router = Router()
      ..get('/health', _healthHandler)
      ..get('/openapi.yaml', _openapiSpecHandler)
      ..get('/api/projects', _listProjectsHandler)
      ..get('/api/agents', _listAgentsHandler)
      ..post('/api/sessions', _createSessionHandler)
      ..get('/api/sessions', _listSessionsHandler)
      ..get('/api/sessions/<id>', _getSessionHandler)
      ..get('/api/sessions/<id>/events', _getSessionEventsHandler)
      ..post('/api/sessions/<id>/cancel', _cancelSessionHandler)
      ..get('/ws/sessions/<id>', _sessionWebSocketHandler);

    return const Pipeline()
        .addMiddleware(requestLogger())
        .addMiddleware(corsMiddleware())
        .addMiddleware(_rateLimiter.middleware())
        .addMiddleware(_errorHandler())
        .addHandler(router.call);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ERROR HANDLING MIDDLEWARE
  // ──────────────────────────────────────────────────────────────────────────

  Middleware _errorHandler() {
    return (Handler inner) {
      return (Request request) async {
        try {
          return await inner(request);
        } on HijackException {
          // HijackException is used for WebSocket upgrades - rethrow it
          rethrow;
        } on FormatException catch (e) {
          return _jsonResponse(
            {'error': 'Invalid JSON format: ${e.message}'},
            statusCode: 400,
          );
        } on _ValidationException catch (e) {
          return _jsonResponse({'error': e.message}, statusCode: 400);
        } catch (e, stackTrace) {
          stderr.writeln('Unhandled error: $e\n$stackTrace');
          return _jsonResponse(
            {'error': 'Internal server error'},
            statusCode: 500,
          );
        }
      };
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REST HANDLERS
  // ──────────────────────────────────────────────────────────────────────────

  Response _healthHandler(Request request) {
    return _jsonResponse({
      'status': 'ok',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'version': '1.0.0',
      'sessions': {
        'active': _sessions.values
            .where((s) => s.state == SessionState.running)
            .length,
        'total': _sessions.length,
      },
    });
  }

  Response _openapiSpecHandler(Request request) {
    return Response.ok(_openapiYaml, headers: {'Content-Type': 'text/yaml'});
  }

  Response _listProjectsHandler(Request request) {
    final projects = _projects.values.map((p) => p.toJson()).toList();
    return _jsonResponse(projects);
  }

  Response _listAgentsHandler(Request request) {
    final agents = _agents.values.map((a) => a.toJson()).toList();
    return _jsonResponse(agents);
  }

  Response _listSessionsHandler(Request request) {
    // Optional filtering by state
    final stateFilter = request.url.queryParameters['state'];
    var sessions = _sessions.values;

    if (stateFilter != null) {
      final state = SessionState.values.where((s) => s.name == stateFilter);
      if (state.isNotEmpty) {
        sessions = sessions.where((s) => s.state == state.first);
      }
    }

    // Sort by createdAt descending
    final sortedSessions = sessions.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _jsonResponse(sortedSessions.map((s) => s.toJson()).toList());
  }

  Future<Response> _createSessionHandler(Request request) async {
    // Check session limit
    final activeSessions =
        _sessions.values.where((s) => s.state == SessionState.running).length;
    if (activeSessions >= maxConcurrentSessions) {
      return _jsonResponse(
        {'error': 'Maximum concurrent sessions reached. Please try later.'},
        statusCode: 503,
      );
    }

    final bodyString = await request.readAsString();
    if (bodyString.isEmpty) {
      throw _ValidationException('Request body is required');
    }

    final body = jsonDecode(bodyString) as Map<String, dynamic>;

    // Validate required fields
    final agentId = _validateString(body, 'agentId', maxLength: 50);
    final projectId = _validateString(body, 'projectId', maxLength: 50);
    final prompt = _validateString(body, 'prompt', maxLength: maxPromptLength);

    // Validate agent exists
    if (!_agents.containsKey(agentId)) {
      return _jsonResponse(
        {'error': 'Unknown agent: $agentId'},
        statusCode: 400,
      );
    }

    // Validate project exists
    if (!_projects.containsKey(projectId)) {
      return _jsonResponse(
        {'error': 'Unknown project: $projectId'},
        statusCode: 400,
      );
    }

    final sessionId = _generateSecureId();
    final session = Session(
      id: sessionId,
      agentId: agentId,
      projectId: projectId,
      prompt: prompt,
    );
    _sessions[sessionId] = session;

    final controller = StreamController<SessionEvent>.broadcast();
    _eventStreams[sessionId] = controller;
    _wsConnections[sessionId] = {};

    // Kick off ACP session in background
    unawaited(_runAcpSession(session, controller));

    return _jsonResponse(
      {'id': sessionId, 'state': session.state.name},
      statusCode: 201,
    );
  }

  Response _getSessionHandler(Request request, String id) {
    final sanitizedId = _sanitizeId(id);
    final session = _sessions[sanitizedId];
    if (session == null) {
      return _jsonResponse({'error': 'Session not found'}, statusCode: 404);
    }
    return _jsonResponse(session.toJson());
  }

  Response _getSessionEventsHandler(Request request, String id) {
    final sanitizedId = _sanitizeId(id);
    final session = _sessions[sanitizedId];
    if (session == null) {
      return _jsonResponse({'error': 'Session not found'}, statusCode: 404);
    }

    // Optional pagination
    final offset = int.tryParse(request.url.queryParameters['offset'] ?? '0');
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '100');

    var events = session.events.map((e) => e.toJson()).toList();
    if (offset != null && offset > 0 && offset < events.length) {
      events = events.skip(offset).toList();
    }
    if (limit != null && limit > 0 && limit < events.length) {
      events = events.take(limit).toList();
    }

    return _jsonResponse(events);
  }

  Future<Response> _cancelSessionHandler(Request request, String id) async {
    final sanitizedId = _sanitizeId(id);
    final session = _sessions[sanitizedId];
    if (session == null) {
      return _jsonResponse({'error': 'Session not found'}, statusCode: 404);
    }

    if (session.state != SessionState.running) {
      return _jsonResponse(
        {'error': 'Session is not running', 'state': session.state.name},
        statusCode: 400,
      );
    }

    // Mark session as cancelled
    session.state = SessionState.cancelled;
    session.updatedAt = DateTime.now();

    // Add cancellation event
    final event = SessionEvent(
      id: _generateSecureId(),
      sessionId: session.id,
      type: SessionEventType.cancelled,
      payload: {'message': 'Session cancelled by user'},
    );
    session.events.add(event);

    // Notify WebSocket clients
    final controller = _eventStreams[sanitizedId];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
      await controller.close();
    }

    return _jsonResponse({'id': session.id, 'state': session.state.name});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WEBSOCKET HANDLER
  // ──────────────────────────────────────────────────────────────────────────

  FutureOr<Response> _sessionWebSocketHandler(Request request, String id) {
    final sanitizedId = _sanitizeId(id);
    final session = _sessions[sanitizedId];
    if (session == null) {
      return Response.notFound(
        jsonEncode({'error': 'Session not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return webSocketHandler((WebSocketChannel socket) {
      // Track connection
      _wsConnections[sanitizedId]?.add(socket);

      // Send existing events
      for (final event in session.events) {
        socket.sink.add(jsonEncode(event.toJson()));
      }

      // Stream new events
      StreamSubscription<SessionEvent>? subscription;
      // ignore: close_sinks - controller is managed by class lifecycle
      final controller = _eventStreams[sanitizedId];
      if (controller != null && !controller.isClosed) {
        subscription = controller.stream.listen(
          (event) {
            try {
              socket.sink.add(jsonEncode(event.toJson()));
            } catch (_) {
              // Client disconnected
            }
          },
          onError: (Object error) {
            // Log but don't crash
            stderr.writeln('WebSocket stream error: $error');
          },
        );
      }

      // Handle client messages (for future interactive features)
      socket.stream.listen(
        (message) {
          // Handle incoming messages if needed
          // For now, we just ignore client messages
        },
        onDone: () {
          subscription?.cancel();
          _wsConnections[sanitizedId]?.remove(socket);
        },
        onError: (Object error) {
          subscription?.cancel();
          _wsConnections[sanitizedId]?.remove(socket);
        },
      );
    })(request);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ACP SESSION (stub implementation - replace with real acp_dart calls)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _runAcpSession(
    Session session,
    StreamController<SessionEvent> stream,
  ) async {
    try {
      await _addEvent(session, stream, SessionEventType.plan, {
        'message': 'Planning edits for: ${session.prompt}',
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      if (session.state == SessionState.cancelled) return;

      await _addEvent(session, stream, SessionEventType.log, {
        'line': 'Analyzing project files...',
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      if (session.state == SessionState.cancelled) return;

      await _addEvent(session, stream, SessionEventType.diff, {
        'file': 'lib/main.dart',
        'diff': '@@ -1,5 +1,5 @@\n- old\n+ new',
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      if (session.state == SessionState.cancelled) return;

      session.state = SessionState.done;
      session.updatedAt = DateTime.now();

      await _addEvent(session, stream, SessionEventType.log, {
        'line': 'Session completed successfully',
      });
    } catch (e, stackTrace) {
      stderr.writeln('ACP session error: $e\n$stackTrace');
      session.state = SessionState.failed;
      session.updatedAt = DateTime.now();

      await _addEvent(session, stream, SessionEventType.error, {
        'message': 'Session failed: $e',
      });
    } finally {
      if (!stream.isClosed) {
        await stream.close();
      }
    }
  }

  Future<void> _addEvent(
    Session session,
    StreamController<SessionEvent> stream,
    SessionEventType type,
    Map<String, dynamic> payload,
  ) async {
    final event = SessionEvent(
      id: _generateSecureId(),
      sessionId: session.id,
      type: type,
      payload: payload,
    );
    session.events.add(event);
    session.updatedAt = DateTime.now();

    if (!stream.isClosed) {
      stream.add(event);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ──────────────────────────────────────────────────────────────────────────

  String _generateSecureId() => _uuid.v4();

  String _sanitizeId(String id) {
    // Only allow alphanumeric, dash, and underscore
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
  }

  String _validateString(
    Map<String, dynamic> data,
    String field, {
    int maxLength = 255,
  }) {
    final value = data[field];
    if (value == null) {
      throw _ValidationException('Missing required field: $field');
    }
    if (value is! String) {
      throw _ValidationException('Field $field must be a string');
    }
    if (value.isEmpty) {
      throw _ValidationException('Field $field cannot be empty');
    }
    if (value.length > maxLength) {
      throw _ValidationException(
        'Field $field exceeds maximum length of $maxLength',
      );
    }
    return value;
  }

  Response _jsonResponse(Object data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Disposes resources. Call when shutting down the service.
  void dispose() {
    _rateLimiter.dispose();
    // Copy values to avoid concurrent modification
    final controllers = _eventStreams.values.toList();
    for (final controller in controllers) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    final allConnections = _wsConnections.values.expand((s) => s.toList()).toList();
    for (final ws in allConnections) {
      try {
        ws.sink.close();
      } catch (_) {
        // Ignore close errors
      }
    }
    _eventStreams.clear();
    _wsConnections.clear();
  }

  // For testing
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);
  Map<String, Project> get projects => Map.unmodifiable(_projects);
  Map<String, Agent> get agents => Map.unmodifiable(_agents);
}

class _ValidationException implements Exception {
  final String message;
  _ValidationException(this.message);

  @override
  String toString() => message;
}

// ────────────────────────────────────────────────────────────────────────────
// OPENAPI SPEC
// ────────────────────────────────────────────────────────────────────────────

const _openapiYaml = '''
openapi: 3.1.0
info:
  title: Agent Control Plane API
  version: 1.0.0
  description: REST API for managing ACP-based coding agent sessions

servers:
  - url: http://localhost:8080
    description: Local development server

paths:
  /health:
    get:
      summary: Health check endpoint
      operationId: getHealth
      responses:
        '200':
          description: Service is healthy
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: string
                  timestamp:
                    type: string
                    format: date-time
                  version:
                    type: string

  /api/projects:
    get:
      summary: List all projects
      operationId: listProjects
      responses:
        '200':
          description: List of projects
          content:
            application/json:
              schema:
                type: array
                items:
                  \$ref: '#/components/schemas/Project'

  /api/agents:
    get:
      summary: List all agents
      operationId: listAgents
      responses:
        '200':
          description: List of agents
          content:
            application/json:
              schema:
                type: array
                items:
                  \$ref: '#/components/schemas/Agent'

  /api/sessions:
    get:
      summary: List all sessions
      operationId: listSessions
      parameters:
        - name: state
          in: query
          description: Filter by session state
          schema:
            type: string
            enum: [running, done, failed, cancelled]
      responses:
        '200':
          description: List of sessions
          content:
            application/json:
              schema:
                type: array
                items:
                  \$ref: '#/components/schemas/Session'

    post:
      summary: Create a new agent session
      operationId: createSession
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [agentId, projectId, prompt]
              properties:
                agentId:
                  type: string
                  maxLength: 50
                projectId:
                  type: string
                  maxLength: 50
                prompt:
                  type: string
                  maxLength: 10000
      responses:
        '201':
          description: Session created
          content:
            application/json:
              schema:
                type: object
                properties:
                  id:
                    type: string
                  state:
                    type: string
        '400':
          description: Invalid request
        '503':
          description: Maximum concurrent sessions reached

  /api/sessions/{id}:
    get:
      summary: Get session metadata
      operationId: getSession
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Session details
          content:
            application/json:
              schema:
                \$ref: '#/components/schemas/Session'
        '404':
          description: Session not found

  /api/sessions/{id}/events:
    get:
      summary: List historical events for a session
      operationId: getSessionEvents
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
        - name: limit
          in: query
          schema:
            type: integer
            default: 100
      responses:
        '200':
          description: List of events
          content:
            application/json:
              schema:
                type: array
                items:
                  \$ref: '#/components/schemas/SessionEvent'
        '404':
          description: Session not found

  /api/sessions/{id}/cancel:
    post:
      summary: Cancel a running session
      operationId: cancelSession
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Session cancelled
          content:
            application/json:
              schema:
                type: object
                properties:
                  id:
                    type: string
                  state:
                    type: string
        '400':
          description: Session is not running
        '404':
          description: Session not found

  /ws/sessions/{id}:
    get:
      summary: WebSocket stream of session events
      operationId: streamSessionEvents
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '101':
          description: Switching protocols to WebSocket

components:
  schemas:
    Project:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        path:
          type: string

    Agent:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        status:
          type: string
          enum: [available, busy, offline]

    Session:
      type: object
      properties:
        id:
          type: string
        agentId:
          type: string
        projectId:
          type: string
        prompt:
          type: string
        state:
          type: string
          enum: [running, done, failed, cancelled]
        createdAt:
          type: string
          format: date-time
        updatedAt:
          type: string
          format: date-time

    SessionEvent:
      type: object
      properties:
        id:
          type: string
        sessionId:
          type: string
        type:
          type: string
          enum: [plan, log, diff, action, toolResult, error, cancelled]
        payload:
          type: object
        timestamp:
          type: string
          format: date-time
''';
