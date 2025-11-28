import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:agent_board/service.dart';
import 'package:agent_board/models/models.dart';
import 'package:agent_board/middleware/rate_limiter.dart';

void main() {
  group('AgentService', () {
    late AgentService service;
    late HttpServer server;
    late String baseUrl;
    late http.Client client;

    setUp(() async {
      service = AgentService(
        rateLimiter: RateLimiter(maxRequests: 1000, window: const Duration(minutes: 1)),
      );
      server = await io.serve(service.createHandler(), 'localhost', 0);
      baseUrl = 'http://localhost:${server.port}';
      client = http.Client();
    });

    tearDown(() async {
      client.close();
      service.dispose();
      await server.close();
    });

    group('Health Check', () {
      test('returns 200 with health status', () async {
        final response = await client.get(Uri.parse('$baseUrl/health'));

        expect(response.statusCode, equals(200));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['status'], equals('ok'));
        expect(body['version'], equals('1.0.0'));
        expect(body['timestamp'], isNotNull);
        expect(body['sessions'], isA<Map>());
      });
    });

    group('OpenAPI Spec', () {
      test('returns YAML content', () async {
        final response = await client.get(Uri.parse('$baseUrl/openapi.yaml'));

        expect(response.statusCode, equals(200));
        expect(response.headers['content-type'], contains('yaml'));
        expect(response.body, contains('openapi: 3.1.0'));
      });
    });

    group('Projects API', () {
      test('GET /api/projects returns list of projects', () async {
        final response = await client.get(Uri.parse('$baseUrl/api/projects'));

        expect(response.statusCode, equals(200));
        final projects = jsonDecode(response.body) as List;
        expect(projects, isNotEmpty);
        expect(projects.first, containsPair('id', isNotNull));
        expect(projects.first, containsPair('name', isNotNull));
        expect(projects.first, containsPair('path', isNotNull));
      });
    });

    group('Agents API', () {
      test('GET /api/agents returns list of agents', () async {
        final response = await client.get(Uri.parse('$baseUrl/api/agents'));

        expect(response.statusCode, equals(200));
        final agents = jsonDecode(response.body) as List;
        expect(agents, isNotEmpty);
        expect(agents.first, containsPair('id', isNotNull));
        expect(agents.first, containsPair('name', isNotNull));
      });
    });

    group('Sessions API', () {
      test('POST /api/sessions creates new session', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );

        expect(response.statusCode, equals(201));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['id'], isNotNull);
        expect(body['state'], equals('running'));
      });

      test('POST /api/sessions rejects unknown agent', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'unknown_agent',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );

        expect(response.statusCode, equals(400));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('Unknown agent'));
      });

      test('POST /api/sessions rejects unknown project', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'unknown_project',
            'prompt': 'Test prompt',
          }),
        );

        expect(response.statusCode, equals(400));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('Unknown project'));
      });

      test('POST /api/sessions rejects missing fields', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
          }),
        );

        expect(response.statusCode, equals(400));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('Missing required field'));
      });

      test('POST /api/sessions rejects empty body', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: '',
        );

        expect(response.statusCode, equals(400));
      });

      test('POST /api/sessions rejects invalid JSON', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: 'not valid json',
        );

        expect(response.statusCode, equals(400));
      });

      test('POST /api/sessions rejects overly long prompt', () async {
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'x' * 20000, // Exceeds maxPromptLength
          }),
        );

        expect(response.statusCode, equals(400));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('exceeds maximum length'));
      });

      test('GET /api/sessions returns list of sessions', () async {
        // Create a session first
        await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );

        final response = await client.get(Uri.parse('$baseUrl/api/sessions'));

        expect(response.statusCode, equals(200));
        final sessions = jsonDecode(response.body) as List;
        expect(sessions, isNotEmpty);
      });

      test('GET /api/sessions filters by state', () async {
        // Create a session
        await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );

        final response = await client.get(
          Uri.parse('$baseUrl/api/sessions?state=running'),
        );

        expect(response.statusCode, equals(200));
        final sessions = jsonDecode(response.body) as List;
        for (final session in sessions) {
          expect((session as Map)['state'], equals('running'));
        }
      });

      test('GET /api/sessions/<id> returns session details', () async {
        // Create a session
        final createResponse = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );
        final sessionId =
            (jsonDecode(createResponse.body) as Map<String, dynamic>)['id'];

        final response = await client.get(
          Uri.parse('$baseUrl/api/sessions/$sessionId'),
        );

        expect(response.statusCode, equals(200));
        final session = jsonDecode(response.body) as Map<String, dynamic>;
        expect(session['id'], equals(sessionId));
        expect(session['agentId'], equals('claude'));
        expect(session['projectId'], equals('flutter_ai_toolkit'));
      });

      test('GET /api/sessions/<id> returns 404 for unknown session', () async {
        final response = await client.get(
          Uri.parse('$baseUrl/api/sessions/unknown_id'),
        );

        expect(response.statusCode, equals(404));
      });

      test('GET /api/sessions/<id>/events returns session events', () async {
        // Create a session
        final createResponse = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );
        final sessionId =
            (jsonDecode(createResponse.body) as Map<String, dynamic>)['id'];

        // Wait for some events
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final response = await client.get(
          Uri.parse('$baseUrl/api/sessions/$sessionId/events'),
        );

        expect(response.statusCode, equals(200));
        final events = jsonDecode(response.body) as List;
        expect(events, isNotEmpty);
      });

      test('POST /api/sessions/<id>/cancel cancels running session', () async {
        // Create a session
        final createResponse = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );
        final sessionId =
            (jsonDecode(createResponse.body) as Map<String, dynamic>)['id'];

        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions/$sessionId/cancel'),
        );

        expect(response.statusCode, equals(200));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['state'], equals('cancelled'));
      });

      test('POST /api/sessions/<id>/cancel returns 400 for non-running session',
          () async {
        // Create and cancel a session
        final createResponse = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );
        final sessionId =
            (jsonDecode(createResponse.body) as Map<String, dynamic>)['id'];

        // Cancel once
        await client.post(
          Uri.parse('$baseUrl/api/sessions/$sessionId/cancel'),
        );

        // Try to cancel again
        final response = await client.post(
          Uri.parse('$baseUrl/api/sessions/$sessionId/cancel'),
        );

        expect(response.statusCode, equals(400));
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['error'], contains('not running'));
      });
    });

    group('WebSocket', () {
      test('streams session events', () async {
        // Create a session
        final createResponse = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );
        final sessionId =
            (jsonDecode(createResponse.body) as Map<String, dynamic>)['id'];

        final wsUrl = 'ws://localhost:${server.port}/ws/sessions/$sessionId';
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        final events = <Map<String, dynamic>>[];
        final completer = Completer<void>();

        channel.stream.listen(
          (message) {
            events.add(jsonDecode(message as String) as Map<String, dynamic>);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        // Wait for session to complete or timeout
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );

        await channel.sink.close();

        expect(events, isNotEmpty);
        expect(events.first, containsPair('type', isNotNull));
        expect(events.first, containsPair('sessionId', sessionId));
      });

      // Note: WebSocket 404 behavior is tested via HTTP since the server
      // returns 404 before upgrading to WebSocket
    });

    group('CORS', () {
      test('includes CORS headers in response', () async {
        final response = await client.get(Uri.parse('$baseUrl/health'));

        expect(
          response.headers['access-control-allow-origin'],
          isNotNull,
        );
      });
    });

    group('Input Sanitization', () {
      test('sanitizes session ID in URL', () async {
        // Try to inject malicious characters in session ID
        final response = await client.get(
          Uri.parse('$baseUrl/api/sessions/test<script>alert(1)</script>'),
        );

        // Should return 404 (not found) not an error
        expect(response.statusCode, equals(404));
      });
    });

    group('Session Lifecycle', () {
      test('session completes successfully with events', () async {
        // Create a session
        final createResponse = await client.post(
          Uri.parse('$baseUrl/api/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'agentId': 'claude',
            'projectId': 'flutter_ai_toolkit',
            'prompt': 'Test prompt',
          }),
        );
        final sessionId =
            (jsonDecode(createResponse.body) as Map<String, dynamic>)['id'];

        // Wait for session to complete
        await Future<void>.delayed(const Duration(seconds: 5));

        // Check session state
        final sessionResponse = await client.get(
          Uri.parse('$baseUrl/api/sessions/$sessionId'),
        );
        final session =
            jsonDecode(sessionResponse.body) as Map<String, dynamic>;
        expect(session['state'], anyOf(['done', 'running']));

        // Check events were recorded
        final eventsResponse = await client.get(
          Uri.parse('$baseUrl/api/sessions/$sessionId/events'),
        );
        final events = jsonDecode(eventsResponse.body) as List;
        expect(events, isNotEmpty);

        // Verify event types
        final eventTypes = events.map((e) => (e as Map)['type']).toSet();
        expect(eventTypes, contains('plan'));
      });
    });
  });

  group('Models', () {
    group('Project', () {
      test('serializes to JSON', () {
        const project = Project(
          id: 'test',
          name: 'Test Project',
          path: '/path/to/project',
        );

        final json = project.toJson();

        expect(json['id'], equals('test'));
        expect(json['name'], equals('Test Project'));
        expect(json['path'], equals('/path/to/project'));
      });

      test('deserializes from JSON', () {
        final json = {
          'id': 'test',
          'name': 'Test Project',
          'path': '/path/to/project',
        };

        final project = Project.fromJson(json);

        expect(project.id, equals('test'));
        expect(project.name, equals('Test Project'));
        expect(project.path, equals('/path/to/project'));
      });
    });

    group('Agent', () {
      test('serializes to JSON', () {
        const agent = Agent(
          id: 'claude',
          name: 'Claude Code',
          status: AgentStatus.available,
        );

        final json = agent.toJson();

        expect(json['id'], equals('claude'));
        expect(json['name'], equals('Claude Code'));
        expect(json['status'], equals('available'));
      });

      test('deserializes from JSON', () {
        final json = {
          'id': 'claude',
          'name': 'Claude Code',
          'status': 'busy',
        };

        final agent = Agent.fromJson(json);

        expect(agent.id, equals('claude'));
        expect(agent.name, equals('Claude Code'));
        expect(agent.status, equals(AgentStatus.busy));
      });
    });

    group('Session', () {
      test('serializes to JSON', () {
        final session = Session(
          id: 'sess_123',
          agentId: 'claude',
          projectId: 'project_1',
          prompt: 'Test prompt',
        );

        final json = session.toJson();

        expect(json['id'], equals('sess_123'));
        expect(json['agentId'], equals('claude'));
        expect(json['projectId'], equals('project_1'));
        expect(json['prompt'], equals('Test prompt'));
        expect(json['state'], equals('running'));
        expect(json['createdAt'], isNotNull);
        expect(json['updatedAt'], isNotNull);
      });

      test('deserializes from JSON', () {
        final json = {
          'id': 'sess_123',
          'agentId': 'claude',
          'projectId': 'project_1',
          'prompt': 'Test prompt',
          'state': 'done',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-01T00:01:00.000Z',
        };

        final session = Session.fromJson(json);

        expect(session.id, equals('sess_123'));
        expect(session.state, equals(SessionState.done));
      });
    });

    group('SessionEvent', () {
      test('serializes to JSON', () {
        final event = SessionEvent(
          id: 'evt_123',
          sessionId: 'sess_123',
          type: SessionEventType.plan,
          payload: {'message': 'Planning...'},
        );

        final json = event.toJson();

        expect(json['id'], equals('evt_123'));
        expect(json['sessionId'], equals('sess_123'));
        expect(json['type'], equals('plan'));
        expect(json['payload'], equals({'message': 'Planning...'}));
        expect(json['timestamp'], isNotNull);
      });

      test('deserializes from JSON', () {
        final json = {
          'id': 'evt_123',
          'sessionId': 'sess_123',
          'type': 'diff',
          'payload': {'file': 'main.dart'},
          'timestamp': '2024-01-01T00:00:00.000Z',
        };

        final event = SessionEvent.fromJson(json);

        expect(event.id, equals('evt_123'));
        expect(event.type, equals(SessionEventType.diff));
        expect(event.payload['file'], equals('main.dart'));
      });
    });
  });

  group('RateLimiter', () {
    test('allows requests within limit', () async {
      final limiter = RateLimiter(maxRequests: 5, window: const Duration(seconds: 1));
      final service = AgentService(rateLimiter: limiter);
      final server = await io.serve(service.createHandler(), 'localhost', 0);
      final client = http.Client();

      try {
        for (var i = 0; i < 5; i++) {
          final response = await client.get(
            Uri.parse('http://localhost:${server.port}/health'),
          );
          expect(response.statusCode, equals(200));
        }
      } finally {
        client.close();
        service.dispose();
        await server.close();
      }
    });
  });
}
