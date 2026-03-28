import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'circuit_breaker.dart';
import 'piped_api_client.dart';
import 'remote_config_service.dart';

/// Health state for a single Piped instance.
class _InstanceHealth {
  final String url;
  bool isHealthy = true;
  DateTime? lastFailure;

  _InstanceHealth({required this.url});
}

/// Manages multiple Piped instances with health-checked failover.
///
/// On failure, marks an instance unhealthy for [_unhealthyCooldown] and
/// rotates to the next healthy one.  A [CircuitBreaker] protects the entire
/// Piped tier from cascading timeouts.
class PipedPool {
  final List<String> _instanceUrls;
  final Map<String, _InstanceHealth> _health = {};
  final Map<String, PipedApiClient> _clients = {};
  final CircuitBreaker _circuitBreaker;
  final Duration _unhealthyCooldown;
  int _currentIndex = 0;

  PipedPool({
    List<String>? instances,
    CircuitBreaker? circuitBreaker,
    Duration unhealthyCooldown = const Duration(minutes: 5),
  })  : _instanceUrls = (instances?.isNotEmpty == true
                ? instances!
                : RemoteConfigService.instance.pipedInstances)
            .where((u) => u.isNotEmpty)
            .toList(),
        _circuitBreaker = circuitBreaker ??
            CircuitBreaker(
              failureThreshold: 3,
              cooldownDuration: const Duration(minutes: 15),
            ),
        _unhealthyCooldown = unhealthyCooldown {
    for (final url in _instanceUrls) {
      _health[url] = _InstanceHealth(url: url);
    }
  }

  /// Execute [action] against the next healthy Piped instance, cycling
  /// through all instances on failure.
  ///
  /// Throws if all instances are down or the circuit breaker is open.
  Future<T> executeWithFailover<T>(
    Future<T> Function(PipedApiClient client) action,
  ) async {
    if (_circuitBreaker.isOpen) {
      throw PipedPoolExhaustedException(
          'Piped circuit breaker open — all instances recently failed');
    }
    if (_instanceUrls.isEmpty) {
      throw PipedPoolExhaustedException('No Piped instances configured');
    }

    for (var i = 0; i < _instanceUrls.length; i++) {
      final url = _nextHealthyUrl();
      if (url == null) break;

      final client =
          _clients.putIfAbsent(url, () => PipedApiClient(baseUrl: url));
      try {
        final result = await action(client);
        _markHealthy(url);
        _circuitBreaker.recordSuccess();
        return result;
      } catch (e) {
        debugPrint('PipedPool: instance $url failed: $e');
        _markUnhealthy(url);
      }
    }

    _circuitBreaker.recordFailure();
    throw PipedPoolExhaustedException(
      'All ${_instanceUrls.length} Piped instances failed',
    );
  }

  /// Run a health check against all instances (GET /trending with 5s timeout).
  Future<Map<String, bool>> healthCheck() async {
    final results = <String, bool>{};
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

    for (final url in _instanceUrls) {
      try {
        final response = await dio.get(
          '$url/trending',
          queryParameters: {'region': 'US'},
        );
        final healthy = response.statusCode == 200;
        _health[url]!.isHealthy = healthy;
        if (healthy) _health[url]!.lastFailure = null;
        results[url] = healthy;
      } catch (_) {
        _health[url]!.isHealthy = false;
        _health[url]!.lastFailure = DateTime.now();
        results[url] = false;
      }
    }

    dio.close();
    return results;
  }

  // -- Internal --------------------------------------------------------------

  String? _nextHealthyUrl() {
    final now = DateTime.now();
    for (var i = 0; i < _instanceUrls.length; i++) {
      final url = _instanceUrls[(_currentIndex + i) % _instanceUrls.length];
      final h = _health[url]!;
      if (h.isHealthy) {
        _currentIndex = (_currentIndex + i + 1) % _instanceUrls.length;
        return url;
      }
      // Check cooldown expiry.
      if (h.lastFailure != null &&
          now.difference(h.lastFailure!) >= _unhealthyCooldown) {
        _currentIndex = (_currentIndex + i + 1) % _instanceUrls.length;
        return url;
      }
    }
    return null;
  }

  void _markHealthy(String url) {
    final h = _health[url];
    if (h != null) {
      h.isHealthy = true;
      h.lastFailure = null;
    }
  }

  void _markUnhealthy(String url) {
    final h = _health[url];
    if (h != null) {
      h.isHealthy = false;
      h.lastFailure = DateTime.now();
    }
  }
}

/// Thrown when all Piped instances in the pool are exhausted.
class PipedPoolExhaustedException implements Exception {
  final String message;
  const PipedPoolExhaustedException(this.message);

  @override
  String toString() => 'PipedPoolExhaustedException: $message';
}
