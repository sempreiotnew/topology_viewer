import 'package:flutter/material.dart';
import '../models/topology_data.dart';

class TopologyStatusBar extends StatelessWidget {
  final bool connected;
  final String statusMsg;
  final TopologyData? topology;
  /// When non-null, shows a second MQTT indicator dot (used in CENTRAL mode
  /// where both serial and MQTT are active independently).
  final bool? mqttConnected;

  const TopologyStatusBar({
    super.key,
    required this.connected,
    required this.statusMsg,
    required this.topology,
    this.mqttConnected,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        connected ? const Color(0xFF00FF9C) : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFF0A1018),
      child: Row(
        children: [
          // ── Serial / main connection dot ───────────────────────────────────
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withAlpha(200), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusMsg,
            style: TextStyle(
              color: color.withAlpha(230),
              fontSize: 11,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
          // ── MQTT indicator (only shown in CENTRAL mode) ────────────────────
          if (mqttConnected != null) ...[
            const SizedBox(width: 16),
            _mqttDot(mqttConnected!),
          ],
          const Spacer(),
          if (topology != null) ...[
            _statChip(
              'ACK',
              '${topology!.acked}/${topology!.total}',
              const Color(0xFF00FF9C),
            ),
            const SizedBox(width: 8),
            _statChip('RTX', '${topology!.retries}', const Color(0xFFFFB347)),
            const SizedBox(width: 8),
            _statChip('SEQ', '${topology!.seq}', const Color(0xFF90EE90)),
          ],
        ],
      ),
    );
  }

  Widget _mqttDot(bool isConnected) {
    final Color mqttColor =
        isConnected ? const Color(0xFF00BFFF) : const Color(0xFF607080);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mqttColor,
            boxShadow: [
              BoxShadow(color: mqttColor.withAlpha(180), blurRadius: 5),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isConnected ? 'MQTT' : 'MQTT off',
          style: TextStyle(
            color: mqttColor.withAlpha(210),
            fontSize: 10,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: color.withAlpha(153),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
