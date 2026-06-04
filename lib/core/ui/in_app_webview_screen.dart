import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Navegador web embebido: enlaces http/https se abren en la misma vista.
class InAppWebViewScreen extends StatefulWidget {
  const InAppWebViewScreen({super.key, required this.initialUrl});

  final String initialUrl;

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _canGoBack = false;

  static bool _isWebScheme(WebUri? uri) {
    final scheme = (uri?.scheme ?? '').toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<void> _updateNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final back = await controller.canGoBack();
    if (!mounted) return;
    setState(() => _canGoBack = back);
  }

  Future<NavigationActionPolicy> _onShouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    if (_isWebScheme(uri)) return NavigationActionPolicy.ALLOW;

    final parsed = Uri.tryParse(uri.toString());
    if (parsed != null && await canLaunchUrl(parsed)) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
    return NavigationActionPolicy.CANCEL;
  }

  Future<bool> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction createWindowAction,
  ) async {
    final target = createWindowAction.request.url;
    if (target != null && _isWebScheme(target)) {
      await controller.loadUrl(urlRequest: URLRequest(url: target));
    }
    return true;
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      await _updateNavigationState();
      return;
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final initial = WebUri(widget.initialUrl);

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _handleBack,
          ),
          title: const Text(''),
        ),
        body: Column(
          children: [
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 2,
              ),
            Expanded(
              child: InAppWebView(
              initialUrlRequest: URLRequest(url: initial),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (_, _) => _updateNavigationState(),
              onLoadStop: (_, _) => _updateNavigationState(),
              onProgressChanged: (_, progress) {
                setState(() => _progress = progress / 100);
              },
              shouldOverrideUrlLoading: _onShouldOverrideUrlLoading,
              onCreateWindow: _onCreateWindow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
