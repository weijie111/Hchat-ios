import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Native：WebView 承载地图 HTML（与发现页小程序同源依赖）。
class LocationMapHost extends StatefulWidget {
  final String html;
  final String baseUrl;
  final ValueChanged<String> onBridgeMessage;
  final VoidCallback? onLoadError;

  const LocationMapHost({
    super.key,
    required this.html,
    required this.baseUrl,
    required this.onBridgeMessage,
    this.onLoadError,
  });

  @override
  State<LocationMapHost> createState() => _LocationMapHostState();
}

class _LocationMapHostState extends State<LocationMapHost> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE8EAED))
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (_) {
          widget.onLoadError?.call();
        },
      ))
      ..addJavaScriptChannel('LocationBridge', onMessageReceived: (msg) {
        widget.onBridgeMessage(msg.message);
      });
    // Android：放行 H5 geolocation 授权弹窗
    try {
      final p = wc.platform;
      if (p is AndroidWebViewController) {
        await p.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (params) async =>
              const GeolocationPermissionsResponse(allow: true, retain: false),
        );
      }
    } catch (_) {}
    await wc.loadHtmlString(widget.html, baseUrl: widget.baseUrl);
    if (!mounted) return;
    setState(() => _controller = wc);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: c);
  }
}
