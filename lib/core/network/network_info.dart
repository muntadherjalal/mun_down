/// Contract for checking network connectivity.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Concrete implementation of [NetworkInfo].
///
/// Uses a simple connectivity check. Can be swapped for
/// a `connectivity_plus`-backed implementation later.
class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // TODO: Replace with a real connectivity check (e.g. connectivity_plus).
    return true;
  }
}
