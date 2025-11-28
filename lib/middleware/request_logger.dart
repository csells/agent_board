import 'dart:io';
import 'package:shelf/shelf.dart';

/// Creates a logging middleware that outputs structured logs.
Middleware requestLogger({
  void Function(String message, Level level)? logger,
}) {
  final log = logger ?? _defaultLogger;

  return (Handler inner) {
    return (Request request) async {
      final startTime = DateTime.now();
      final requestId = _generateRequestId();

      log(
        'REQ [$requestId] ${request.method} ${request.requestedUri.path}',
        Level.info,
      );

      try {
        final response = await inner(request);
        final duration = DateTime.now().difference(startTime);

        final level = response.statusCode >= 500
            ? Level.error
            : response.statusCode >= 400
                ? Level.warning
                : Level.info;

        log(
          'RES [$requestId] ${response.statusCode} ${duration.inMilliseconds}ms',
          level,
        );

        return response.change(headers: {
          ...response.headers,
          'X-Request-Id': requestId,
        });
      } on HijackException {
        // HijackException is used for WebSocket upgrades - don't log as error
        rethrow;
      } catch (e, stackTrace) {
        final duration = DateTime.now().difference(startTime);
        log(
          'ERR [$requestId] $e ${duration.inMilliseconds}ms\n$stackTrace',
          Level.error,
        );
        rethrow;
      }
    };
  };
}

void _defaultLogger(String message, Level level) {
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final levelName = level.name.toUpperCase().padRight(5);
  stderr.writeln('[$timestamp] $levelName $message');
}

String _generateRequestId() {
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

enum Level {
  debug,
  info,
  warning,
  error,
}
