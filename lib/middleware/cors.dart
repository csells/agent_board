import 'package:shelf/shelf.dart';

/// Creates CORS middleware with configurable allowed origins.
///
/// For production, specify a list of allowed origins.
/// For development, you can use ['*'] to allow all origins.
Middleware corsMiddleware({
  List<String> allowedOrigins = const ['*'],
  List<String> allowedMethods = const ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  List<String> allowedHeaders = const ['Content-Type', 'Authorization'],
  int maxAge = 86400,
}) {
  return (Handler inner) {
    return (Request request) async {
      // Handle preflight OPTIONS request
      if (request.method == 'OPTIONS') {
        return _corsResponse(
          Response.ok(''),
          request,
          allowedOrigins,
          allowedMethods,
          allowedHeaders,
          maxAge,
        );
      }

      final response = await inner(request);
      return _corsResponse(
        response,
        request,
        allowedOrigins,
        allowedMethods,
        allowedHeaders,
        maxAge,
      );
    };
  };
}

Response _corsResponse(
  Response response,
  Request request,
  List<String> allowedOrigins,
  List<String> allowedMethods,
  List<String> allowedHeaders,
  int maxAge,
) {
  final origin = request.headers['origin'];
  final allowOrigin = _getAllowedOrigin(origin, allowedOrigins);

  return response.change(headers: {
    ...response.headers,
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': allowedMethods.join(', '),
    'Access-Control-Allow-Headers': allowedHeaders.join(', '),
    'Access-Control-Max-Age': maxAge.toString(),
    if (allowOrigin != '*') 'Vary': 'Origin',
  });
}

String _getAllowedOrigin(String? origin, List<String> allowedOrigins) {
  if (allowedOrigins.contains('*')) {
    return '*';
  }
  if (origin != null && allowedOrigins.contains(origin)) {
    return origin;
  }
  // Return first allowed origin as fallback
  return allowedOrigins.isNotEmpty ? allowedOrigins.first : '';
}
