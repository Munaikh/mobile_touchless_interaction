import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Avenir',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF256B6A),
          brightness: Brightness.light,
        ),
      ),
      home: const TouchlessHome(),
    );
  }
}

class TouchlessHome extends StatefulWidget {
  const TouchlessHome({super.key});

  @override
  State<TouchlessHome> createState() => _TouchlessHomeState();
}

class _TouchlessHomeState extends State<TouchlessHome>
    with SingleTickerProviderStateMixin {
  static const Duration _dwellDuration = Duration(milliseconds: 1100);
  static const Duration _fastDwellDuration = Duration(milliseconds: 1100);
  static const Duration _activationCooldown = Duration(milliseconds: 1200);
  static const double _arcInnerStart = 0.7;
  static const double _arcQuickDepth = 0.86;
  static const double _arcEdgeBuffer = 0.04;
  static const double _returnNeutralThreshold = 0.2;
  static const double _returnPullStrength = 8.0;
  static const double _centerAttenuationRadius = 0.35;
  static const double _centerMinGain = 0.35;

  final List<String> _labels = const [
    'Call',
    'Music',
    'Map',
    'Camera',
    'Message',
    'Torch',
  ];

  StreamSubscription<AccelerometerEvent>? _accelSub;
  late final Ticker _ticker;
  Duration? _lastTick;
  Timer? _dwellTimer;
  DateTime? _lastActivationTime;

  Offset _cursorOffset = Offset.zero;
  Offset _desiredOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  List<Offset> _buttonOffsets = const [];
  int? _hoveredIndex;

  double _circleRadius = 100.0;
  double _buttonRadius = 48.0;
  double _maxCursorRadius = 190.0;

  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;
  double? _neutralX;
  double? _neutralY;
  bool _showDebugOverlay = false;

  void _recenter() {
    final gravityMag = sqrt(
      _gravityX * _gravityX + _gravityY * _gravityY + _gravityZ * _gravityZ,
    );

    if (gravityMag >= 0.1) {
      _neutralX = _gravityX / gravityMag;
      _neutralY = _gravityY / gravityMag;
    }

    _desiredOffset = Offset.zero;
    _targetOffset = Offset.zero;
    _cursorOffset = Offset.zero;
    _updateHover(null);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEventStream().listen(_handleAccelEvent);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker.dispose();
    _dwellTimer?.cancel();
    super.dispose();
  }

  void _handleAccelEvent(AccelerometerEvent event) {
    if (_buttonOffsets.isEmpty) {
      return;
    }

    // Low-pass filter to approximate gravity for tilt direction.
    const double gravityAlpha = 0.5;
    _gravityX = gravityAlpha * _gravityX + (1 - gravityAlpha) * event.x;
    _gravityY = gravityAlpha * _gravityY + (1 - gravityAlpha) * event.y;
    _gravityZ = gravityAlpha * _gravityZ + (1 - gravityAlpha) * event.z;

    final gravityMag = sqrt(
      _gravityX * _gravityX + _gravityY * _gravityY + _gravityZ * _gravityZ,
    );
    if (gravityMag < 0.1) {
      return;
    }

    final normX = _gravityX / gravityMag;
    final normY = _gravityY / gravityMag;

    _neutralX ??= normX;
    _neutralY ??= normY;

    var deltaX = normX - (_neutralX ?? 0.0);
    var deltaY = normY - (_neutralY ?? 0.0);

    const double deadZone = 0.015;
    if (deltaX.abs() < deadZone) {
      deltaX = 0.0;
    }
    if (deltaY.abs() < deadZone) {
      deltaY = 0.0;
    }

    const double tiltSensitivity = 1150.0;
    var desiredOffset = Offset(-deltaX, deltaY) * tiltSensitivity;
    final desiredRadius = desiredOffset.distance;
    final attenRadius = _circleRadius * _centerAttenuationRadius;
    if (desiredRadius < attenRadius && desiredRadius > 0.0) {
      final t = (desiredRadius / attenRadius).clamp(0.0, 1.0);
      final curved = pow(t, 1.6).toDouble();
      final gain = _centerMinGain + (1 - _centerMinGain) * curved;
      desiredOffset = desiredOffset * gain;
    }
    _desiredOffset = _clampToRadius(desiredOffset, _maxCursorRadius);
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;

    if (last == null || _buttonOffsets.isEmpty) {
      return;
    }

    final dt = ((elapsed - last).inMicroseconds / 1000000.0).clamp(0.005, 0.05);

    const double targetResponse = 6.0;
    final targetSmoothing = (dt * targetResponse).clamp(0.0, 1.0);
    _targetOffset += (_desiredOffset - _targetOffset) * targetSmoothing;

    const double cursorResponse = 20.0;
    final cursorSmoothing = (dt * cursorResponse).clamp(0.0, 1.0);
    var nextCursor =
        _cursorOffset + (_targetOffset - _cursorOffset) * cursorSmoothing;

    const double maxCursorSpeed = 1750.0;
    final delta = nextCursor - _cursorOffset;
    final maxStep = maxCursorSpeed * dt;
    if (delta.distance > maxStep) {
      nextCursor = _cursorOffset + delta / delta.distance * maxStep;
    }

    nextCursor = _clampToRadius(nextCursor, _maxCursorRadius);

    final neutralThreshold = _circleRadius * _returnNeutralThreshold;
    if (_desiredOffset.distance < neutralThreshold && nextCursor.distance > 0) {
      final pull = (_returnPullStrength * dt).clamp(0.0, 0.85);
      nextCursor = nextCursor * (1 - pull);
    }

    int? hovered;
    var quick = false;
    hovered = _findHoveredIndex(nextCursor);
    quick = hovered != null && _isQuickHover(nextCursor);

    _cursorOffset = nextCursor;
    _updateHover(hovered, quick: quick);

    if (mounted) {
      setState(() {});
    }
  }

  Offset _clampToRadius(Offset offset, double radius) {
    final dist = offset.distance;
    if (dist <= radius) {
      return offset;
    }
    return offset / dist * radius;
  }

  int? _findHoveredIndex(Offset cursorOffset) {
    if (_buttonOffsets.isEmpty) {
      return null;
    }

    final depthThreshold = _circleRadius * _arcInnerStart;
    final radial = cursorOffset.distance;
    if (radial < depthThreshold) {
      return null;
    }

    final angle = atan2(cursorOffset.dy, cursorOffset.dx);
    final step = (2 * pi) / _labels.length;
    final normalized = (angle + pi / 2 + 2 * pi) % (2 * pi);
    final rawIndex = (normalized / step).floor().clamp(0, _labels.length - 1);
    final centerAngle = -pi / 2 + step * rawIndex + step / 2;
    final diff = ((angle - centerAngle + pi) % (2 * pi)) - pi;
    var edgeBuffer = step * _arcEdgeBuffer;
    if (_hoveredIndex == rawIndex) {
      edgeBuffer *= 0.7;
    }
    if (diff.abs() > (step / 2 - edgeBuffer)) {
      if (radial >= _circleRadius * _arcQuickDepth) {
        final roundedIndex = (normalized / step).round() % _labels.length;
        return roundedIndex;
      }
      return null;
    }
    return rawIndex;
  }

  bool _isQuickHover(Offset cursorOffset) {
    return cursorOffset.distance >= _circleRadius * _arcQuickDepth;
  }

  void _updateHover(int? index, {bool quick = false}) {
    if (index == _hoveredIndex) {
      return;
    }

    _hoveredIndex = index;
    _dwellTimer?.cancel();

    if (index != null) {
      HapticFeedback.selectionClick();
      final dwell = quick ? _fastDwellDuration : _dwellDuration;
      _dwellTimer = Timer(dwell, () => _activate(index));
    }
  }

  void _activate(int index) {
    final now = DateTime.now();
    final lastActivation = _lastActivationTime;

    if (lastActivation != null &&
        now.difference(lastActivation) < _activationCooldown) {
      return;
    }

    _lastActivationTime = now;
    HapticFeedback.mediumImpact();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activated ${_labels[index]}'),
        duration: const Duration(milliseconds: 900),
      ),
    );

    setState(() {});
  }

  void _recalculateLayout(Size size) {
    final minSide = min(size.width, size.height);
    _circleRadius = minSide * 0.28;
    _buttonRadius = minSide * 0.085;
    _maxCursorRadius = _circleRadius + _buttonRadius * 0.8;

    final step = (2 * pi) / _labels.length;
    _buttonOffsets = List.generate(_labels.length, (index) {
      final angle = -pi / 2 + step * index;
      return Offset(cos(angle), sin(angle)) * _circleRadius;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _recalculateLayout(constraints.biggest);
          final center = Offset(
            constraints.biggest.width / 2,
            constraints.biggest.height / 2,
          );

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6F1E9), Color(0xFFE5ECEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Title and Instructions
                Positioned(
                  top: 48,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Touchless Hover',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tilt the device to move the cursor. Hold over a button\nfor a moment to activate it with haptics.',
                        style: TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
                // Recenter + Debug
                Positioned(
                  bottom: 52,
                  right: 24,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _recenter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF256B6A),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.center_focus_strong, size: 16),
                        label: const Text('Recenter'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showDebugOverlay = !_showDebugOverlay;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF256B6A),
                          side: const BorderSide(
                            color: Color(0xFF256B6A),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(
                          _showDebugOverlay
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 16,
                        ),
                        label: Text(_showDebugOverlay ? 'Hide Debug' : 'Debug'),
                      ),
                    ],
                  ),
                ),
                // Circle
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: _circleRadius * 2.2,
                        height: _circleRadius * 2.2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFCAD5D4),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showDebugOverlay)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DebugOverlayPainter(
                          labelsCount: _labels.length,
                          circleRadius: _circleRadius,
                          maxCursorRadius: _maxCursorRadius,
                          arcInnerStart: _arcInnerStart,
                          arcQuickDepth: _arcQuickDepth,
                          arcEdgeBuffer: _arcEdgeBuffer,
                          cursorOffset: _cursorOffset,
                        ),
                      ),
                    ),
                  ),
                // Buttons
                ..._labels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final label = entry.value;
                  final offset = _buttonOffsets[index];
                  final isHovered = _hoveredIndex == index;

                  return Positioned(
                    left: center.dx + offset.dx - _buttonRadius,
                    top: center.dy + offset.dy - _buttonRadius,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: isHovered ? 1.08 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _buttonRadius * 2,
                        height: _buttonRadius * 2,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? const Color(0xFF256B6A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: isHovered ? 18 : 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: isHovered
                                ? const Color(0xFF1F5957)
                                : const Color(0xFFE0E6E6),
                            width: isHovered ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isHovered ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Cursor
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DebugOverlayPainter extends CustomPainter {
  _DebugOverlayPainter({
    required this.labelsCount,
    required this.circleRadius,
    required this.maxCursorRadius,
    required this.arcInnerStart,
    required this.arcQuickDepth,
    required this.arcEdgeBuffer,
    required this.cursorOffset,
  });

  final int labelsCount;
  final double circleRadius;
  final double maxCursorRadius;
  final double arcInnerStart;
  final double arcQuickDepth;
  final double arcEdgeBuffer;
  final Offset cursorOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    outlinePaint.color = Colors.blueGrey.withOpacity(0.35);
    canvas.drawCircle(center, maxCursorRadius, outlinePaint);

    outlinePaint.color = Colors.deepPurple.withOpacity(0.4);
    canvas.drawCircle(center, circleRadius * arcInnerStart, outlinePaint);

    outlinePaint.color = Colors.teal.withOpacity(0.4);
    canvas.drawCircle(center, circleRadius * arcQuickDepth, outlinePaint);

    final step = (2 * pi) / labelsCount;
    final arcPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.withOpacity(0.08);
    final innerRadius = circleRadius * arcInnerStart;

    for (var i = 0; i < labelsCount; i++) {
      final start = -pi / 2 + step * i + step * arcEdgeBuffer;
      final end = -pi / 2 + step * (i + 1) - step * arcEdgeBuffer;
      if (end <= start) {
        continue;
      }
      final path = Path()
        ..moveTo(
          center.dx + cos(start) * innerRadius,
          center.dy + sin(start) * innerRadius,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          start,
          end - start,
          false,
        )
        ..lineTo(
          center.dx + cos(end) * circleRadius,
          center.dy + sin(end) * circleRadius,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: circleRadius),
          end,
          start - end,
          false,
        )
        ..close();
      canvas.drawPath(path, arcPaint);
    }

    final cursorPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red.withOpacity(0.8);
    canvas.drawCircle(center + cursorOffset, 5, cursorPaint);
  }

  @override
  bool shouldRepaint(covariant _DebugOverlayPainter oldDelegate) {
    return labelsCount != oldDelegate.labelsCount ||
        circleRadius != oldDelegate.circleRadius ||
        maxCursorRadius != oldDelegate.maxCursorRadius ||
        arcInnerStart != oldDelegate.arcInnerStart ||
        arcQuickDepth != oldDelegate.arcQuickDepth ||
        arcEdgeBuffer != oldDelegate.arcEdgeBuffer ||
        cursorOffset != oldDelegate.cursorOffset;
  }
}
