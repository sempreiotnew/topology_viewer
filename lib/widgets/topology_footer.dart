import 'package:flutter/material.dart';

class TopologyFooter extends StatelessWidget {
  const TopologyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1018),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — node state dots
          Row(
            children: [
              _legendDot(const Color(0xFF00FF9C), 'ROOT'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFF00FF9C), 'ACTIVE'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFF607080), 'OFFLINE'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFFFFB347), 'UNACKED'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFFFF2222), 'ALARM'),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2 — RSSI quality legend (3 levels)
          Row(
            children: [
              Text(
                'SIGNAL: ',
                style: TextStyle(
                  color: Colors.white.withAlpha(60),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
              _legendLine(const Color(0xFF00FF9C), 'GOOD ≥−70'),
              const SizedBox(width: 12),
              _legendLine(const Color(0xFFFFB347), 'MEDIUM ≥−80'),
              const SizedBox(width: 12),
              _legendLine(const Color(0xFFFF6B6B), 'LOW <−80'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendLine(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16, height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color.withAlpha(200), fontSize: 9, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withAlpha(153), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withAlpha(200),
            fontSize: 9,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
