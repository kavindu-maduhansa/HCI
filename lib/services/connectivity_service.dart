import 'package:connectivity_plus/connectivity_plus.dart';

/// #offline-banner - a thin wrapper around `connectivity_plus` so the
/// rest of the app depends on a simple `Stream<bool> isOffline` rather
/// than the plugin's own `List<ConnectivityResult>` shape. This
/// reports real device/network connectivity - it does NOT guarantee
/// Firestore itself is reachable (a captive portal or a firewalled
/// network can report "connected" while still blocking Firestore),
/// which is why the banner text below is worded as "changes will
/// sync when you're back online" rather than a stronger claim.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();

  Stream<bool> get isOffline => _connectivity.onConnectivityChanged.map(_isOffline);

  Future<bool> checkIsOffline() async => _isOffline(await _connectivity.checkConnectivity());

  bool _isOffline(List<ConnectivityResult> results) {
    return results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  }
}
