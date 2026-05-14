import 'package:flutter/material.dart';

class MetaChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;

  const MetaChip({
    super.key,
    required this.text,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
        border: outlined
            ? Border.all(color: color.withAlpha(60), width: 0.8)
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
