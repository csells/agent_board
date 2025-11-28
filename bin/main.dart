import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;

import 'package:agent_board/service.dart';

/// Agent Board Service Entry Point
///
/// Run with: dart run bin/main.dart
/// Or: dart run bin/main.dart --port 3000
void main(List<String> args) async {
  // Parse command line arguments
  final port = _parsePort(args);
  final host = _parseHost(args);

  final service = AgentService();
  final handler = service.createHandler();

  final server = await io.serve(handler, host, port);

  stdout.writeln('Agent Board Service running on http://${server.address.host}:${server.port}');
  stdout.writeln('Health check: http://${server.address.host}:${server.port}/health');
  stdout.writeln('OpenAPI spec: http://${server.address.host}:${server.port}/openapi.yaml');
  stdout.writeln('Press Ctrl+C to stop');

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down...');
    service.dispose();
    await server.close();
    exit(0);
  });
}

int _parsePort(List<String> args) {
  const defaultPort = 8080;
  final portIndex = args.indexOf('--port');
  if (portIndex >= 0 && portIndex < args.length - 1) {
    final port = int.tryParse(args[portIndex + 1]);
    if (port != null && port > 0 && port < 65536) {
      return port;
    }
  }
  // Check environment variable
  final envPort = Platform.environment['PORT'];
  if (envPort != null) {
    final port = int.tryParse(envPort);
    if (port != null && port > 0 && port < 65536) {
      return port;
    }
  }
  return defaultPort;
}

String _parseHost(List<String> args) {
  const defaultHost = '0.0.0.0';
  final hostIndex = args.indexOf('--host');
  if (hostIndex >= 0 && hostIndex < args.length - 1) {
    return args[hostIndex + 1];
  }
  return Platform.environment['HOST'] ?? defaultHost;
}
