import 'package:flutter/material.dart';

class TopologyEmptyState extends StatelessWidget {
  final bool connected;

  const TopologyEmptyState({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.device_hub_rounded,
            size: 64,
            color: Color(0xFF1A2D45),
          ),
          const SizedBox(height: 16),
          const Text(
            'AWAITING NETWORK DATA',
            style: TextStyle(
              color: Color(0xFF2A4060),
              fontSize: 14,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? 'Listening on serial port…'
                : 'Connect a device or press DEMO',
            style: const TextStyle(
              color: Color(0xFF1A3050),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
