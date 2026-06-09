import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Bottom-sheet de cámara para escanear códigos de barras / QR.
///
/// Se cierra automáticamente al detectar un código y devuelve el valor
/// escaneado via [Navigator.pop]. Si el usuario cierra sin escanear, devuelve null.
///
/// Uso:
/// ```dart
/// final code = await BarcodeScannerSheet.show(context);
/// if (code != null) { ... }
/// ```
class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const BarcodeScannerSheet(),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  late final MobileScannerController _controller;
  bool _detected = false;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null || code.isEmpty) return;

    _detected = true;
    _lastCode = code;
    setState(() {});

    // Pequeña pausa para que el usuario vea el feedback visual antes de cerrar.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.of(context).pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screenHeight * 0.72,
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Escanear código de barras',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Apunta la cámara al código del producto',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // ── Visor de cámara ──────────────────────────────────────────────
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                    bottom: Radius.circular(12),
                  ),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                ),

                // Overlay oscuro con ventana transparente
                _ScanOverlay(detected: _detected),

                // Código detectado — feedback visual
                if (_detected && _lastCode != null)
                  Positioned(
                    bottom: 32,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                  ),

                // Botón linterna
                Positioned(
                  top: 16,
                  right: 16,
                  child: _TorchButton(controller: _controller),
                ),
              ],
            ),
          ),

          // ── Cancelar ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay con ventana rectangular de escaneo ────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(detected: detected),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.detected});

  final bool detected;

  @override
  void paint(Canvas canvas, Size size) {
    const cutW = 260.0;
    const cutH = 160.0;
    final cutLeft = (size.width - cutW) / 2;
    final cutTop = (size.height - cutH) / 2 - 20;
    final cutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutLeft, cutTop, cutW, cutH),
      const Radius.circular(12),
    );

    // Fondo oscuro semi-transparente con hueco
    final bgPaint = Paint()..color = Colors.black54;
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(cutRect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, holePath),
      bgPaint,
    );

    // Borde del visor (verde si detectado, blanco si no)
    final borderPaint = Paint()
      ..color = detected ? const Color(0xFF22C55E) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = detected ? 3 : 2;
    canvas.drawRRect(cutRect, borderPaint);

    // Esquinas resaltadas
    _drawCorners(canvas, cutLeft, cutTop, cutW, cutH, borderPaint);
  }

  void _drawCorners(Canvas c, double l, double t, double w, double h, Paint p) {
    const len = 20.0;
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
      c.drawPath(path, p..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.detected != detected;
}

// ── Botón linterna ────────────────────────────────────────────────────────────

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
      onTap: () {
        widget.controller.toggleTorch();
        setState(() => _on = !_on);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
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
