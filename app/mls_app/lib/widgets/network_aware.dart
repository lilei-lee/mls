/// 全局断网检测 — 离线时顶部红条提醒
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkAware extends StatefulWidget {
  final Widget child;
  const NetworkAware({super.key, required this.child});

  @override
  State<NetworkAware> createState() => _NetworkAwareState();
}

class _NetworkAwareState extends State<NetworkAware> {
  late StreamSubscription<List<ConnectivityResult>> _sub;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online != _online && mounted) setState(() => _online = online);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (!_online)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: Colors.red.shade700,
          child: const SafeArea(
            bottom: false,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 14),
              SizedBox(width: 8),
              Text('网络已断开,请检查连接', style: TextStyle(color: Colors.white, fontSize: 12.0)),
            ]),
          ),
        ),
      Expanded(child: widget.child),
    ]);
  }
}
