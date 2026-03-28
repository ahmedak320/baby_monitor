/// Generic circuit breaker to prevent cascading timeout storms.
///
/// States:
/// - Closed (normal): requests pass through, failures are counted.
/// - Open: failures exceeded threshold, requests are rejected for [cooldownDuration].
/// - Half-Open: cooldown elapsed, a single probe request is allowed.
class CircuitBreaker {
  final int failureThreshold;
  final Duration cooldownDuration;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  bool _probing = false;

  CircuitBreaker({
    this.failureThreshold = 3,
    this.cooldownDuration = const Duration(minutes: 15),
  });

  /// Whether the circuit is open (rejecting requests).
  bool get isOpen {
    if (_consecutiveFailures < failureThreshold) return false;
    if (_openedAt == null) return false;
    // If cooldown has elapsed, allow a probe (half-open).
    if (DateTime.now().difference(_openedAt!) >= cooldownDuration) return false;
    return true;
  }

  /// Whether the circuit is in half-open state (cooldown elapsed, probe allowed).
  bool get isHalfOpen {
    if (_consecutiveFailures < failureThreshold) return false;
    if (_openedAt == null) return false;
    return DateTime.now().difference(_openedAt!) >= cooldownDuration;
  }

  /// Record a successful request. Resets the circuit to closed.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _probing = false;
  }

  /// Record a failed request. May trip the circuit open.
  void recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= failureThreshold && _openedAt == null) {
      _openedAt = DateTime.now();
    }
    // If we were probing and it failed, reset the cooldown timer.
    if (_probing) {
      _openedAt = DateTime.now();
      _probing = false;
    }
  }

  /// Execute [action] through the circuit breaker.
  ///
  /// Throws [CircuitOpenException] if the circuit is open and not ready to probe.
  Future<T> execute<T>(Future<T> Function() action) async {
    if (isOpen) {
      throw CircuitOpenException('Circuit breaker is open');
    }

    // If half-open, allow one probe.
    if (isHalfOpen) {
      _probing = true;
    }

    try {
      final result = await action();
      recordSuccess();
      return result;
    } catch (e) {
      recordFailure();
      rethrow;
    }
  }

  /// Reset the circuit breaker to its initial closed state.
  void reset() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _probing = false;
  }
}

/// Thrown when a circuit breaker is open and not accepting requests.
class CircuitOpenException implements Exception {
  final String message;
  const CircuitOpenException(this.message);

  @override
  String toString() => 'CircuitOpenException: $message';
}
