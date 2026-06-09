import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/visual_scan/domain/visual_scan_launch_args.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla full-screen estilo Amazon Lens: cámara + galería + código/QR.
class VisualScanLensSheet extends StatefulWidget {
  const VisualScanLensSheet({
    super.key,
    required this.allowPhotoCapture,
  });

  final bool allowPhotoCapture;

  static Future<VisualScanLaunchArgs?> open(
    BuildContext context, {
    required bool allowPhotoCapture,
  }) {
    return Navigator.of(context, rootNavigator: true).push<VisualScanLaunchArgs>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return VisualScanLensSheet(allowPhotoCapture: allowPhotoCapture);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<VisualScanLensSheet> createState() => _VisualScanLensSheetState();
}

class _VisualScanLensSheetState extends State<VisualScanLensSheet> {
  final _picker = ImagePicker();
  late final MobileScannerController _scannerController;
  late bool _barcodeMode;
  bool _detected = false;
  bool _picking = false;
  String? _lastCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Sin permiso de fotos → entra directo a escaneo.
    _barcodeMode = !widget.allowPhotoCapture;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (!mounted) return;
      if (file != null) {
        Navigator.of(context).pop(
          VisualScanLaunchArgs(
            photos: [file.path],
            autoAnalyze: true,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _enterBarcodeMode() {
    setState(() {
      _barcodeMode = true;
      _detected = false;
      _lastCode = null;
      _error = null;
    });
    _scannerController.start();
  }

  void _exitBarcodeMode() {
    setState(() {
      _barcodeMode = false;
      _detected = false;
      _lastCode = null;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_barcodeMode || _detected) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    _detected = true;
    _lastCode = code;
    setState(() {});

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      Navigator.of(context).pop(
        VisualScanLaunchArgs(barcode: code, autoAnalyze: true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowPhoto = widget.allowPhotoCapture;
    final hint = _barcodeMode
        ? 'Centra el código dentro del recuadro'
        : allowPhoto
            ? 'Toma una foto para buscar productos'
            : 'Centra el código dentro del recuadro';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            key: ValueKey('scanner-$_barcodeMode'),
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          if (_barcodeMode)
            _ScanOverlayLayer(detected: _detected),

          if (!_barcodeMode)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0, 0.22, 0.62, 1],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(context),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    if (_detected && _lastCode != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _lastCode!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _buildControls(allowPhoto),
                    const SizedBox(height: 16),
                  ],
                ),
                if (_barcodeMode)
                  Positioned(
                    top: 56,
                    right: 12,
                    child: _TorchButton(controller: _scannerController),
                  ),
              ],
            ),
          ),

          if (_picking)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Exel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppDecorations.brandGradient.createShader(bounds),
                  child: const Text(
                    'Lens',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.catalogAccent.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildControls(bool allowPhoto) {
    if (_barcodeMode) {
      return Column(
        children: [
          if (allowPhoto)
            TextButton(
              onPressed: _exitBarcodeMode,
              child: const Text(
                'Volver a foto',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _LensCircleButton(
            size: 52,
            icon: Icons.photo_library_outlined,
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
          _LensShutterButton(
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
          _LensCircleButton(
            size: 52,
            icon: Icons.qr_code_scanner,
            onTap: _enterBarcodeMode,
          ),
        ],
      ),
    );
  }
}

// ── Recuadro de escaneo (mismo estilo que BarcodeScannerSheet) ───────────────

class _ScanOverlayLayer extends StatelessWidget {
  const _ScanOverlayLayer({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _OverlayPainter(detected: detected),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.detected});

  final bool detected;

  @override
  void paint(Canvas canvas, Size size) {
    const cutW = 280.0;
    const cutH = 180.0;
    final cutLeft = (size.width - cutW) / 2;
    final cutTop = (size.height - cutH) / 2 - 40;
    final cutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutLeft, cutTop, cutW, cutH),
      const Radius.circular(14),
    );

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.58);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(cutRect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, holePath),
      bgPaint,
    );

    final borderPaint = Paint()
      ..color = detected ? const Color(0xFF22C55E) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = detected ? 3 : 2.5;
    canvas.drawRRect(cutRect, borderPaint);

    _drawCorners(canvas, cutLeft, cutTop, cutW, cutH, borderPaint);
  }

  void _drawCorners(Canvas c, double l, double t, double w, double h, Paint p) {
    const len = 24.0;
    final r = l + w;
    final b = t + h;
    final paths = [
      [Offset(l, t + len), Offset(l, t), Offset(l + len, t)],
      [Offset(r - len, t), Offset(r, t), Offset(r, t + len)],
      [Offset(l, b - len), Offset(l, b), Offset(l + len, b)],
      [Offset(r - len, b), Offset(r, b), Offset(r, b - len)],
    ];
    for (final pts in paths) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      c.drawPath(path, p..strokeWidth = 3.5);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.detected != detected;
}

class _TorchButton extends StatefulWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  State<_TorchButton> createState() => _TorchButtonState();
}

class _TorchButtonState extends State<_TorchButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await widget.controller.toggleTorch();
        setState(() => _on = !_on);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _on ? Colors.amber.withValues(alpha: 0.9) : Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _on ? Icons.flashlight_on : Icons.flashlight_off,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _LensCircleButton extends StatelessWidget {
  const _LensCircleButton({
    required this.size,
    required this.icon,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.black87, size: size * 0.42),
        ),
      ),
    );
  }
}

class _LensShutterButton extends StatelessWidget {
  const _LensShutterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            size: 32,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
