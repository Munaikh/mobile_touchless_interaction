import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef TouchlessRingItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      bool isHovered,
      double size,
      Widget child,
    );

class TouchlessRing extends StatefulWidget {
  const TouchlessRing({
    super.key,
    required this.items,
    this.itemBuilder,
    this.onActivate,
    this.dwellDuration = const Duration(milliseconds: 1100),
    this.fastDwellDuration = const Duration(milliseconds: 1100),
    this.activationCooldown = const Duration(milliseconds: 1200),
    this.showRecenterButton = true,
    this.showDebugToggle = true,
    this.initialDebugOverlay = false,
  });

  final List<Widget> items;
  final TouchlessRingItemBuilder? itemBuilder;
  final ValueChanged<int>? onActivate;
  final Duration dwellDuration;
  final Duration fastDwellDuration;
  final Duration activationCooldown;
  final bool showRecenterButton;
  final bool showDebugToggle;
  final bool initialDebugOverlay;

  @override
  State<TouchlessRing> createState() => _TouchlessRingState();
}

class _TouchlessRingState extends State<TouchlessRing>
    with SingleTickerProviderStateMixin {
  static const double _arcInnerStart = 0.7;
  static const double _arcQuickDepth = 0.86;
  static const double _arcEdgeBuffer = 0.04;
  static const double _returnNeutralThreshold = 0.2;
  static const double _returnPullStrength = 8.0;
  static const double _centerAttenuationRadius = 0.35;
  static const double _centerMinGain = 0.35;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  late final Ticker _ticker;
  Duration? _lastTick;
  Timer? _dwellTimer;
  DateTime? _lastActivationTime;
  DateTime? _hoverStartTime;
  Duration? _activeDwellDuration;
  bool _isQuickHoverMode = false;

  Offset _cursorOffset = Offset.zero;
  Offset _desiredOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  List<Offset> _itemOffsets = const [];
  int? _hoveredIndex;

  double _circleRadius = 100.0;
  double _buttonRadius = 48.0;
  double _maxCursorRadius = 190.0;

  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;
  double? _neutralX;
  double? _neutralY;
  late bool _showDebugOverlay;

  @override
  void initState() {
    super.initState();
    _showDebugOverlay = widget.initialDebugOverlay;
    _accelSub = accelerometerEventStream().listen(_handleAccelEvent);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(TouchlessRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      if (_hoveredIndex != null && _hoveredIndex! >= widget.items.length) {
        _updateHover(null);
      }
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker.dispose();
    _dwellTimer?.cancel();
    super.dispose();
  }

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

  void _handleAccelEvent(AccelerometerEvent event) {
    if (_itemOffsets.isEmpty) {
      return;
    }

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

    if (last == null || _itemOffsets.isEmpty) {
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

    final hovered = _findHoveredIndex(nextCursor);
    final quick = hovered != null && _isQuickHover(nextCursor);

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
    if (_itemOffsets.isEmpty) {
      return null;
    }

    final depthThreshold = _circleRadius * _arcInnerStart;
    final radial = cursorOffset.distance;
    if (radial < depthThreshold) {
      return null;
    }

    final angle = atan2(cursorOffset.dy, cursorOffset.dx);
    final step = (2 * pi) / _itemOffsets.length;
    final normalized = (angle + pi / 2 + 2 * pi) % (2 * pi);
    final rawIndex = (normalized / step).floor().clamp(
      0,
      _itemOffsets.length - 1,
    );
    final centerAngle = -pi / 2 + step * rawIndex + step / 2;
    final diff = ((angle - centerAngle + pi) % (2 * pi)) - pi;
    var edgeBuffer = step * _arcEdgeBuffer;
    if (_hoveredIndex == rawIndex) {
      edgeBuffer *= 0.7;
    }
    if (diff.abs() > (step / 2 - edgeBuffer)) {
      if (radial >= _circleRadius * _arcQuickDepth) {
        final roundedIndex = (normalized / step).round() % _itemOffsets.length;
        return roundedIndex;
      }
      return null;
    }
    return rawIndex;
  }

  bool _isQuickHover(Offset cursorOffset) {
    return cursorOffset.distance >= _circleRadius * _arcQuickDepth;
  }

  double _hoverProgress() {
    final start = _hoverStartTime;
    final dwell = _activeDwellDuration;
    if (_hoveredIndex == null || start == null || dwell == null) {
      return 0.0;
    }

    final dwellMicros = dwell.inMicroseconds;
    if (dwellMicros <= 0) {
      return 1.0;
    }

    final elapsed = DateTime.now().difference(start).inMicroseconds;
    return (elapsed / dwellMicros).clamp(0.0, 1.0).toDouble();
  }

  void _updateHover(int? index, {bool quick = false}) {
    if (index == _hoveredIndex) {
      if (index == null || quick == _isQuickHoverMode) {
        return;
      }

      final oldDwell = _activeDwellDuration;
      final start = _hoverStartTime;
      if (oldDwell == null || start == null || oldDwell.inMicroseconds <= 0) {
        return;
      }

      final now = DateTime.now();
      final elapsed = now.difference(start).inMicroseconds;
      final progress = (elapsed / oldDwell.inMicroseconds).clamp(0.0, 1.0);
      final newDwell = quick ? widget.fastDwellDuration : widget.dwellDuration;
      final consumed = Duration(
        microseconds: (newDwell.inMicroseconds * progress).round(),
      );

      _isQuickHoverMode = quick;
      _activeDwellDuration = newDwell;
      _hoverStartTime = now.subtract(consumed);
      _dwellTimer?.cancel();
      final remaining = newDwell - consumed;
      if (remaining <= Duration.zero) {
        _activate(index);
      } else {
        _dwellTimer = Timer(remaining, () => _activate(index));
      }
      return;
    }

    _hoveredIndex = index;
    _dwellTimer?.cancel();
    _hoverStartTime = null;
    _activeDwellDuration = null;
    _isQuickHoverMode = quick;

    if (index != null) {
      Haptics.vibrate(HapticsType.rigid);
      final dwell = quick ? widget.fastDwellDuration : widget.dwellDuration;
      _hoverStartTime = DateTime.now();
      _activeDwellDuration = dwell;
      _dwellTimer = Timer(dwell, () => _activate(index));
    }
  }

  void _activate(int index) {
    final now = DateTime.now();
    final lastActivation = _lastActivationTime;

    if (lastActivation != null &&
        now.difference(lastActivation) < widget.activationCooldown) {
      return;
    }

    _lastActivationTime = now;
    Haptics.vibrate(HapticsType.success);
    widget.onActivate?.call(index);
  }

  void _recalculateLayout(Size size) {
    _buttonRadius = size.width * 0.085;
    _circleRadius = max(0, (size.width / 2) - _buttonRadius - 8);
    _maxCursorRadius = _circleRadius + _buttonRadius * 0.8;

    if (widget.items.isEmpty) {
      _itemOffsets = const [];
      return;
    }

    final step = (2 * pi) / widget.items.length;
    _itemOffsets = List.generate(widget.items.length, (index) {
      final angle = -pi / 2 + step * index;
      return Offset(cos(angle), sin(angle)) * _circleRadius;
    });
  }

  Widget _buildDefaultItem(bool isHovered, double size, Widget child) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: isHovered ? 1.08 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isHovered ? const Color(0xFF256B6A) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isHovered ? Colors.white : Colors.black87,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _recalculateLayout(constraints.biggest);
        final center = Offset(
          constraints.biggest.width / 2,
          constraints.biggest.height / 2,
        );
        final buttonSize = _buttonRadius * 2.5;
        final hoverProgress = _hoverProgress();

        return Stack(
          children: [
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
                      labelsCount: widget.items.length,
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
            ...widget.items.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              final offset = _itemOffsets[index];
              final isHovered = _hoveredIndex == index;
              final built =
                  widget.itemBuilder?.call(
                    context,
                    index,
                    isHovered,
                    buttonSize,
                    child,
                  ) ??
                  _buildDefaultItem(isHovered, buttonSize, child);

              return Positioned(
                left: center.dx + offset.dx - buttonSize / 2,
                top: center.dy + offset.dy - buttonSize / 2,
                child: SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: Stack(
                    children: [
                      Positioned.fill(child: built),
                      if (isHovered)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                value: hoverProgress,
                                strokeWidth: 3,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.22,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (widget.showRecenterButton || widget.showDebugToggle)
              Positioned(
                bottom: 52,
                right: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showRecenterButton)
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
                    if (widget.showRecenterButton && widget.showDebugToggle)
                      const SizedBox(width: 10),
                    if (widget.showDebugToggle)
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
          ],
        );
      },
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
    if (labelsCount <= 0) {
      return;
    }

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
