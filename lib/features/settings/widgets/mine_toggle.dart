// 自定义开关，对应原型 .switch / .theme-toggle。
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const Toggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 28,
        decoration: BoxDecoration(
          color: value ? c.accent : c.bgSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: value ? c.accent : c.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c.card,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
