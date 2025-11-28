import 'dart:async';
import 'package:shelf/shelf.dart';

/// Simple in-memory rate limiter middleware.
///
/// Limits requests per IP address within a time window.
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, _RateLimitEntry> _entries = {};
  Timer? _cleanupTimer;

  RateLimiter({
    this.maxRequests = 100,
    this.window = const Duration(minutes: 1),
  }) {
    // Periodically clean up expired entries
    _cleanupTimer = Timer.periodic(window, (_) => _cleanup());
  }

  /// Creates a rate limiting middleware.
  Middleware middleware() {
    return (Handler inner) {
      return (Request request) async {
        final clientIp = _getClientIp(request);

        if (!_isAllowed(clientIp)) {
          return Response(
            429,
            body: '{"error": "Too many requests. Please try again later."}',
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': window.inSeconds.toString(),
            },
          );
        }

        return inner(request);
      };
    };
  }

  String _getClientIp(Request request) {
    // Check X-Forwarded-For header (for reverse proxies)
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded.split(',').first.trim();
    }
    // Fall back to X-Real-IP
    final realIp = request.headers['x-real-ip'];
    if (realIp != null && realIp.isNotEmpty) {
      return realIp;
    }
    // Default to remote IP or 'unknown'
    return request.headers['host'] ?? 'unknown';
  }

  bool _isAllowed(String clientIp) {
    final now = DateTime.now();
    final entry = _entries[clientIp];

    if (entry == null || now.difference(entry.windowStart) >= window) {
      // New window
      _entries[clientIp] = _RateLimitEntry(
        windowStart: now,
        requestCount: 1,
      );
      return true;
    }

    if (entry.requestCount >= maxRequests) {
      return false;
    }

    entry.requestCount++;
    return true;
  }

  void _cleanup() {
    final now = DateTime.now();
    _entries.removeWhere(
      (_, entry) => now.difference(entry.windowStart) >= window,
    );
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _entries.clear();
  }
}

class _RateLimitEntry {
  final DateTime windowStart;
  int requestCount;

  _RateLimitEntry({
    required this.windowStart,
    required this.requestCount,
  });
}
