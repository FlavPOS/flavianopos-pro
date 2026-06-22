import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps connectivity_plus and exposes a simple online/offline stream.
class ConnectivityWatcher {
  ConnectivityWatcher._();
  static final ConnectivityWatcher instance = ConnectivityWatcher._();

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;

  bool get isOnline => _online;
  Stream<bool> get onChange => _controller.stream;

  Future<void> start() async {
    // Initial check
    final res = await Connectivity().checkConnectivity();
    _online = _hasNetwork(res);
    _controller.add(_online);
    _sub ??= Connectivity().onConnectivityChanged.listen((res) {
      final now = _hasNetwork(res);
      if (now != _online) {
        _online = now;
        _controller.add(_online);
      }
    });
  }

  bool _hasNetwork(List<ConnectivityResult> res) {
    return res.any((r) => r != ConnectivityResult.none);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
