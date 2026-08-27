import 'package:flutter/material.dart';
import '../utils/colors.dart';

class HealthBar extends StatelessWidget {
  final int health;

  const HealthBar({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final double fraction = (health.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vida: $health%'),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: Colors.grey.shade800,
            color: fraction > 0.3 ? AppColors.primary : AppColors.danger,
          ),
        ),
      ],
    );
  }
}
