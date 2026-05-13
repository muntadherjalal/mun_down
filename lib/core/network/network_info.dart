import 'package:connectivity_plus/connectivity_plus.dart';

/// Contract for checking network connectivity.
abstract class NetworkInfo {
  /// Returns `true` if connected to a network.
  Future<bool> get isConnected;

  /// Stream of connectivity changes.
  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

/// Concrete implementation of [NetworkInfo].
///
/// Uses `connectivity_plus` to check device connection status.
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfoImpl() : _connectivity = Connectivity();

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
