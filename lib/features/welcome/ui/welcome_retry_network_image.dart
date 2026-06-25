import 'dart:async';

import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Imagen de red con reintentos automáticos y botón manual si falla.
class WelcomeRetryNetworkImage extends StatefulWidget {
  const WelcomeRetryNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.maxAttempts = 4,
    this.retryDelays = const [
      Duration(milliseconds: 700),
      Duration(milliseconds: 1400),
      Duration(milliseconds: 2800),
    ],
    this.loadingSize = 24,
    this.errorIconSize = 40,
    this.showManualRetry = true,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final int maxAttempts;
  final List<Duration> retryDelays;
  final double loadingSize;
  final double errorIconSize;
  final bool showManualRetry;

  @override
  State<WelcomeRetryNetworkImage> createState() =>
      _WelcomeRetryNetworkImageState();
}

class _WelcomeRetryNetworkImageState extends State<WelcomeRetryNetworkImage> {
  int _attempt = 0;
  bool _waitingRetry = false;
  bool _exhausted = false;
  bool _errorHandledForAttempt = false;
  Timer? _retryTimer;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WelcomeRetryNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _attempt = 0;
      _waitingRetry = false;
      _exhausted = false;
      _errorHandledForAttempt = false;
    }
  }

  String get _requestUrl {
    if (_attempt == 0) return widget.url;
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return widget.url;
    final params = Map<String, String>.from(uri.queryParameters);
    params['_r'] = '$_attempt';
    return uri.replace(queryParameters: params).toString();
  }

  void _onImageError() {
    if (!mounted) return;

    if (_attempt >= widget.maxAttempts - 1) {
      setState(() {
        _exhausted = true;
        _waitingRetry = false;
      });
      return;
    }

    setState(() => _waitingRetry = true);
    _errorHandledForAttempt = false;

    final delayIndex = _attempt.clamp(0, widget.retryDelays.length - 1);
    _retryTimer?.cancel();
    _retryTimer = Timer(widget.retryDelays[delayIndex], () {
      if (!mounted) return;
      setState(() {
        _attempt++;
        _waitingRetry = false;
        _exhausted = false;
      });
    });
  }

  void _manualRetry() {
    _retryTimer?.cancel();
    setState(() {
      _attempt++;
      _waitingRetry = false;
      _exhausted = false;
      _errorHandledForAttempt = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingRetry) {
      return Center(
        child: SizedBox(
          width: widget.loadingSize,
          height: widget.loadingSize,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_exhausted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: widget.errorIconSize,
              color: AppColors.textSecondary.withValues(alpha: 0.55),
            ),
            if (widget.showManualRetry) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _manualRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      );
    }

    return Image.network(
      key: ValueKey('$_requestUrl#$_attempt'),
      _requestUrl,
      width: double.infinity,
      height: double.infinity,
      fit: widget.fit,
      alignment: widget.alignment,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: widget.loadingSize,
            height: widget.loadingSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (!_errorHandledForAttempt) {
          _errorHandledForAttempt = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
        }
        return Center(
          child: SizedBox(
            width: widget.loadingSize,
            height: widget.loadingSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

/// Resuelve dimensiones de imagen de red con reintentos.
Future<({double width, double height})?> resolveNetworkImageSize(
  String url, {
  int maxAttempts = 4,
  List<Duration> retryDelays = const [
    Duration(milliseconds: 700),
    Duration(milliseconds: 1400),
    Duration(milliseconds: 2800),
  ],
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final requestUrl = _urlWithRetryToken(url, attempt);
    final size = await _resolveOnce(requestUrl);
    if (size != null) return size;

    if (attempt < maxAttempts - 1) {
      final delayIndex = attempt.clamp(0, retryDelays.length - 1);
      await Future<void>.delayed(retryDelays[delayIndex]);
    }
  }
  return null;
}

String _urlWithRetryToken(String url, int attempt) {
  if (attempt == 0) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final params = Map<String, String>.from(uri.queryParameters);
  params['_r'] = '$attempt';
  return uri.replace(queryParameters: params).toString();
}

Future<({double width, double height})?> _resolveOnce(String url) async {
  final completer = Completer<({double width, double height})?>();
  final provider = NetworkImage(url);
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;

  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      if (!completer.isCompleted) {
        completer.complete((
          width: info.image.width.toDouble(),
          height: info.image.height.toDouble(),
        ));
      }
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      stream.removeListener(listener);
    },
  );

  stream.addListener(listener);
  return completer.future;
}
