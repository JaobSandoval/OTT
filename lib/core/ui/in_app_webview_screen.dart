import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
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
  String? _loadError;

  static bool get _useHybridComposition =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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

  Future<void> _reload() async {
    setState(() => _loadError = null);
    final controller = _controller;
    if (controller != null) {
      await controller.reload();
      return;
    }
    await InAppWebViewController.clearAllCache();
    if (mounted) setState(() {});
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
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Recargar',
              onPressed: _reload,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 2,
              ),
            Expanded(
              child: _loadError != null
                  ? _ErrorPanel(message: _loadError!, onRetry: _reload)
                  : InAppWebView(
                      initialUrlRequest: URLRequest(url: initial),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        supportMultipleWindows: true,
                        useHybridComposition: _useHybridComposition,
                        allowsInlineMediaPlayback: true,
                        mediaPlaybackRequiresUserGesture: false,
                      ),
                      onWebViewCreated: (controller) {
                        _controller = controller;
                      },
                      onLoadStart: (_, _) {
                        if (_loadError != null) {
                          setState(() => _loadError = null);
                        }
                        _updateNavigationState();
                      },
                      onLoadStop: (_, _) => _updateNavigationState(),
                      onProgressChanged: (_, progress) {
                        setState(() => _progress = progress / 100);
                      },
                      onReceivedError: (controller, request, error) {
                        if (request.isForMainFrame != true) return;
                        if (!mounted) return;
                        setState(() {
                          _loadError =
                              error.description.isNotEmpty
                                  ? error.description
                                  : 'No se pudo cargar la página.';
                        });
                      },
                      onReceivedHttpError: (controller, request, response) {
                        if (request.isForMainFrame != true) return;
                        final code = response.statusCode ?? 0;
                        if (code < 400 || !mounted) return;
                        setState(() {
                          _loadError = 'Error HTTP $code';
                        });
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

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
