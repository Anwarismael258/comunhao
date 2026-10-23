import 'package:flutter/material.dart';

import '../config/supabase_config.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (SupabaseConfig.isProduction) {
      return child;
    }

    final label =
        SupabaseConfig.isStaging ? 'AMBIENTE DE TESTE' : 'DESENVOLVIMENTO';
    final color = SupabaseConfig.isStaging
        ? const Color(0xFFB45309)
        : const Color(0xFF0369A1);

    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withAlpha(230),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
