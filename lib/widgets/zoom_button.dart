import 'package:flutter/material.dart';

class ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const ZoomButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1A3A2C), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF9C).withAlpha(30),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF00FF9C), size: 18),
        ),
      ),
    );
  }
}
