import 'package:flutter/material.dart';

class NodeWidget extends StatefulWidget {
  final String mac;
  final bool isRoot;
  final int layer;
  final int? rssi;
  final bool acked;
  final bool missing;
  final bool isAlarming;

  const NodeWidget({
    super.key,
    required this.mac,
    required this.isRoot,
    required this.layer,
    required this.rssi,
    required this.acked,
    required this.missing,
    required this.isAlarming,
  });

  @override
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  AnimationController? _alarmCtrl;
  Animation<double>? _alarmAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isAlarming) _startAlarm();
  }

  @override
  void didUpdateWidget(NodeWidget old) {
    super.didUpdateWidget(old);
    if (widget.isAlarming && !old.isAlarming) {
      _startAlarm();
    } else if (!widget.isAlarming && old.isAlarming) {
      _stopAlarm();
    }
  }

  void _startAlarm() {
    _alarmCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
    _alarmAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_alarmCtrl!);
    _alarmCtrl!.addListener(() { if (mounted) setState(() {}); });
  }

  void _stopAlarm() {
    _alarmCtrl?.dispose();
    _alarmCtrl = null;
    _alarmAnim = null;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _alarmCtrl?.dispose();
    super.dispose();
  }

  Color get _nodeColor {
    if (widget.isAlarming) return const Color(0xFFFF2222);
    if (widget.isRoot) return const Color(0xFF00FF9C);
    if (widget.missing) return const Color(0xFF607080);
    if (!widget.acked) return const Color(0xFFFFB347);
    return const Color(0xFF00FF9C);
  }

  String get _shortMac {
    final parts = widget.mac.split(':');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}:${parts.last}'.toUpperCase();
    }
    return widget.mac;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _nodeColor;
    final double size = widget.isRoot ? 52.0 : 44.0;

    // Alarm blink: oscillate glow alpha between dim and bright
    final double alarmT = _alarmAnim?.value ?? 0.0;
    final int alarmGlowAlpha = widget.isAlarming
        ? (40 + (alarmT * 200).round()).clamp(40, 240)
        : 64;
    final Color alarmBorderColor = widget.isAlarming
        ? Color.fromARGB((80 + (alarmT * 175).round()).clamp(80, 255),
            color.red, color.green, color.blue)
        : color;

    final Widget nodeContent = SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated outer ring — root only OR alarm blink ring
          if (widget.isRoot || widget.isAlarming)
            AnimatedBuilder(
              animation: widget.isAlarming ? (_alarmCtrl ?? _pulseCtrl) : _pulseAnim,
              builder: (_, __) {
                final double scale = widget.isAlarming
                    ? (1.0 + alarmT * 0.3)
                    : _pulseAnim.value;
                return Container(
                  width: size * scale * 1.5,
                  height: size * scale * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withAlpha(widget.isAlarming
                          ? (alarmT * 180).round().clamp(0, 180)
                          : 38),
                      width: widget.isAlarming ? 2.0 : 1.5,
                    ),
                  ),
                );
              },
            ),

          // Glow halo
          Container(
            width: size + 12,
            height: size + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(widget.missing ? 10 : 20),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(alarmGlowAlpha),
                  blurRadius: widget.isAlarming ? 24 : 18,
                  spreadRadius: widget.isAlarming ? 4 : 2,
                ),
              ],
            ),
          ),

          // Main node circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withAlpha(widget.missing ? 30 : 76), const Color(0xFF0D1520)],
              ),
              border: Border.all(
                color: alarmBorderColor,
                width: widget.isRoot ? 2.5 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.missing
                      ? Icons.wifi_off_rounded
                      : (widget.isRoot ? Icons.router_rounded : Icons.memory_rounded),
                  color: color,
                  size: widget.isRoot ? 18 : 14,
                ),
                Text(
                  _shortMac,
                  style: TextStyle(
                    color: color,
                    fontSize: widget.isRoot ? 8 : 7,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ROOT badge
          if (widget.isRoot)
            Positioned(
              top: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF9C),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'ROOT',
                  style: TextStyle(
                    color: Color(0xFF080C14),
                    fontSize: 7,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          // ALARM badge
          if (widget.isAlarming)
            Positioned(
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2222),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'ALARM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          // Layer badge
          if (!widget.isRoot)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(51),
                  border: Border.all(color: color.withAlpha(128), width: 1),
                ),
                child: Center(
                  child: Text(
                    '${widget.layer}',
                    style: TextStyle(
                      color: color,
                      fontSize: 7,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Faded opacity for offline/missing nodes
    return widget.missing ? Opacity(opacity: 0.38, child: nodeContent) : nodeContent;
  }
}
