import 'package:flutter/material.dart';
import '../models/topology_data.dart';
import '../models/mesh_node.dart';
import '../models/data_pulse.dart';

class EdgePainter extends CustomPainter {
  final TopologyData topology;
  final Map<String, Offset> nodePositions;
  final List<DataPulse> pulses;

  EdgePainter({
    required this.topology,
    required this.nodePositions,
    required this.pulses,
    required Listenable repaint,
  }) : super(repaint: repaint);

  // ── RSSI quality thresholds ──────────────────────────────────────────────
  //   GOOD   : >= -70 dBm  → green
  //   MEDIUM : >= -80 dBm  → amber/yellow
  //   LOW    : <  -80 dBm  → red

  static Color _rssiColor(int? rssi) {
    if (rssi == null) return const Color(0xFF607080);
    if (rssi >= -70) return const Color(0xFF00FF9C); // good   – green
    if (rssi >= -80) return const Color(0xFFFFB347); // medium – amber
    return const Color(0xFFFF6B6B);                  // low    – red
  }

  static String _rssiLabel(int? rssi) {
    if (rssi == null) return '';
    return '${rssi}dBm';
  }

  static double _edgeWidth(int? rssi) {
    if (rssi == null) return 1.2;
    if (rssi >= -70) return 2.5;
    if (rssi >= -80) return 1.8;
    return 1.2;
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const double dashLen = 8.0;
    const double gapLen = 6.0;
    final double totalLen = (to - from).distance;
    if (totalLen == 0) return;
    final Offset dir = (to - from) / totalLen;
    double traveled = 0;
    bool drawing = true;
    while (traveled < totalLen) {
      final double segLen = drawing ? dashLen : gapLen;
      final double end = (traveled + segLen).clamp(0.0, totalLen);
      if (drawing) {
        canvas.drawLine(from + dir * traveled, from + dir * end, paint);
      }
      traveled = end;
      drawing = !drawing;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in topology.nodes) {
      final Offset? from = nodePositions[node.mac];
      final Offset? to = nodePositions[node.parent];
      if (from == null || to == null) continue;

      // ── Offline / missing node: faded dashed gray line, no label ─────────
      if (node.missing) {
        const Color offlineColor = Color(0xFF4A5568);
        _drawDashedLine(
          canvas, from, to,
          Paint()
            ..color = offlineColor.withAlpha(90)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
        continue;
      }

      final Color edgeColor = _rssiColor(node.rssi);
      final double strokeW = _edgeWidth(node.rssi);

      // ── Glow shadow line ─────────────────────────────────────────────────
      canvas.drawLine(
        from, to,
        Paint()
          ..color = edgeColor.withAlpha(45)
          ..strokeWidth = strokeW + 6
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // ── Solid colored edge ───────────────────────────────────────────────
      canvas.drawLine(
        from, to,
        Paint()
          ..color = edgeColor.withAlpha(200)
          ..strokeWidth = strokeW
          ..style = PaintingStyle.stroke,
      );

      // ── RSSI label at mid-point ──────────────────────────────────────────
      final Offset mid = Offset(
        (from.dx + to.dx) / 2,
        (from.dy + to.dy) / 2,
      );
      _drawRssiLabel(canvas, mid, node.rssi, edgeColor, from, to);
    }

    // ── Pulse dots ───────────────────────────────────────────────────────
    for (final pulse in pulses) {
      final Offset? from = nodePositions[pulse.fromMac];
      final Offset? to = nodePositions[pulse.toMac];
      if (from == null || to == null) continue;

      // Find the RSSI for this edge so the pulse dot matches the line color
      MeshNode? edgeNode;
      for (final n in topology.nodes) {
        if (n.mac == pulse.fromMac) { edgeNode = n; break; }
      }
      final Color pulseColor = _rssiColor(edgeNode?.rssi);

      final double t = pulse.progress.value;

      // Trailing glow
      for (int i = 1; i <= 3; i++) {
        final double trailT = (t - i * 0.05).clamp(0.0, 1.0);
        final Offset trailPos = Offset.lerp(from, to, trailT)!;
        final int alpha = ((1.0 - i / 4.0) * 160).round();
        final Color c = pulseColor;
        canvas.drawCircle(
          trailPos,
          (4 - i).toDouble(),
          Paint()..color = Color.fromARGB(alpha, c.red, c.green, c.blue),
        );
      }

      // Core dot
      final Offset pos = Offset.lerp(from, to, t)!;
      canvas.drawCircle(
        pos, 5,
        Paint()
          ..color = pulseColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
    }
  }

  void _drawRssiLabel(
    Canvas canvas,
    Offset mid,
    int? rssi,
    Color color,
    Offset from,
    Offset to,
  ) {
    final String label = _rssiLabel(rssi);

    // Perpendicular offset so the label doesn't sit exactly on the line
    final Offset delta = to - from;
    final double len = delta.distance;
    Offset perp = Offset.zero;
    if (len > 0) {
      // Rotate 90° and normalise, then shift 10px
      perp = Offset(-delta.dy / len, delta.dx / len) * 10;
    }
    final Offset labelPos = mid + perp;

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black.withAlpha(200),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Pill background
    const double padH = 5;
    const double padV = 2;
    final Rect bgRect = Rect.fromCenter(
      center: labelPos,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );
    final RRect rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(4));

    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF080C14).withAlpha(210),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    tp.paint(
      canvas,
      labelPos - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(EdgePainter oldDelegate) => true;
}
