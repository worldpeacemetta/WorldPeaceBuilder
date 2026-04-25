import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/open_food_facts.dart';
import '../theme.dart';

enum _ScanState { scanning, loading, found, error }

/// Bottom sheet that activates the camera to scan a barcode,
/// then resolves the product via Open Food Facts.
/// Pops with a pre-filled food Map on success.
class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  _ScanState _state = _ScanState.scanning;
  String? _errorMessage;
  bool _processed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processed) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _processed = true;

    setState(() => _state = _ScanState.loading);
    await _controller.stop();

    final code = barcode!.rawValue!;
    final food = await fetchFoodByBarcode(code);

    if (!mounted) return;
    if (food != null) {
      Navigator.pop(context, food);
    } else {
      setState(() {
        _state = _ScanState.error;
        _errorMessage = 'Product "$code" not found in Open Food Facts.';
      });
    }
  }

  void _retry() {
    _processed = false;
    _controller.start();
    setState(() { _state = _ScanState.scanning; _errorMessage = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 40),
                const Spacer(),
                const Text('Scan Barcode',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Camera view
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_state == _ScanState.scanning || _state == _ScanState.loading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),

                // Scan frame overlay
                if (_state == _ScanState.scanning)
                  _ScanFrame(),

                // Loading indicator
                if (_state == _ScanState.loading)
                  Container(
                    color: Colors.black54,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: AppColors.protein),
                        SizedBox(height: 12),
                        Text('Looking up product…',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),

                // Error state
                if (_state == _ScanState.error)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off,
                            color: AppColors.danger, size: 52),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage ?? 'Product not found',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Again'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _state == _ScanState.scanning
                  ? 'Point camera at a product barcode'
                  : '',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated corner-bracket scan frame.
class _ScanFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 140,
      child: CustomPaint(painter: _FramePainter()),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.protein
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const r = 10.0;
    const len = 30.0;
    final corners = [
      Offset(0, 0), Offset(size.width, 0),
      Offset(size.width, size.height), Offset(0, size.height),
    ];
    final dirs = [
      [Offset(len, 0), Offset(0, len)],
      [Offset(-len, 0), Offset(0, len)],
      [Offset(-len, 0), Offset(0, -len)],
      [Offset(len, 0), Offset(0, -len)],
    ];
    for (int i = 0; i < 4; i++) {
      final c = corners[i];
      final h = dirs[i][0];
      final v = dirs[i][1];
      canvas.drawLine(c + h, c, paint);
      canvas.drawLine(c, c + v, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
