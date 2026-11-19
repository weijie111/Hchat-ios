import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

/// H5：用 iframe + srcdoc 承载地图 HTML（webview_flutter 在 Flutter Web 不可用）。
///
/// 与 native 共用同一份 HTML：页内若无 LocationBridge（WebView channel），
/// 会 polyfill 成 parent.postMessage；本组件监听后回调 [onBridgeMessage]。
///
/// 布局注意：HtmlElementView 在 Flutter Web 是合成层「洞」，叠在上面的
/// Flutter 控件会被盖住——调用方须把提示条/选点条放在地图上下方（Column），
/// 不要 Stack 叠在地图上。
class LocationMapHost extends StatefulWidget {
  final String html;
  final String baseUrl; // web 端不用（与 io 接口对齐）
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
  StreamSubscription<html.MessageEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = html.window.onMessage.listen(_onMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onMessage(html.MessageEvent ev) {
    final raw = ev.data;
    late final Map<dynamic, dynamic> data;
    if (raw is String) {
      try {
        final j = jsonDecode(raw);
        if (j is! Map) return;
        data = Map<dynamic, dynamic>.from(j);
      } catch (_) {
        return;
      }
    } else if (raw is Map) {
      data = Map<dynamic, dynamic>.from(raw);
    } else {
      return;
    }
    if (data['source'] != 'LocationBridge') return;
    final payload = data['payload'];
    if (payload == null) return;
    widget.onBridgeMessage(payload.toString());
  }

  void _onIFrameCreated(Object element) {
    final iframe = element as html.IFrameElement;
    iframe
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      // 放行 HTML5 / 高德定位（浏览器仍会向用户要权限）
      ..allow = 'geolocation *';
    // srcdoc 文档 origin = 父页面 origin（H5 域名），便于高德 Key 域名白名单
    iframe.srcdoc = widget.html;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _onIFrameCreated,
    );
  }
}
