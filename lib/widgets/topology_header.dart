import 'package:flutter/material.dart';
import '../app_constants.dart';

class TopologyHeader extends StatelessWidget {
  final int messageCount;
  final VoidCallback onLoadDemo;

  const TopologyHeader({
    super.key,
    required this.messageCount,
    required this.onLoadDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1520),
        border:
            Border(bottom: BorderSide(color: Color(0xFF1A2D45), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF00FF9C), Color(0xFF006040)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF9C).withAlpha(100),
                  blurRadius: 12,
                ),
              ],
            ),
            child:
                const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MESH TOPOLOGY',
                style: TextStyle(
                  color: Color(0xFF00FF9C),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'NETWORK MONITOR',
                style: TextStyle(
                  color: const Color(0xFF00FF9C).withAlpha(128),
                  fontSize: 10,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _modeBadge(),
          const Spacer(),
          _glowBadge(
            'MSG #${messageCount.toString().padLeft(4, '0')}',
            const Color(0xFF00FF9C),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onLoadDemo,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1A2D45),
              foregroundColor: const Color(0xFF00FF9C),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeBadge() {
    const bool isCentral = kCentral;
    final Color color =
        isCentral ? const Color(0xFF00BFFF) : const Color(0xFFFFB347);
    final String label = isCentral ? 'CENTRAL' : 'MOBILE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color.withAlpha(160)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _glowBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color.withAlpha(128)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
      ),
    );
  }
}
