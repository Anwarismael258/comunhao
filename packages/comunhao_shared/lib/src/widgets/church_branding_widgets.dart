import 'package:flutter/material.dart';

class ChurchIdentityFrame extends StatelessWidget {
  const ChurchIdentityFrame({
    required this.child,
    required this.primaryColor,
    this.secondaryColor,
    super.key,
  });

  final Widget child;
  final Color primaryColor;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryColor ?? primaryColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }
}

class ChurchIdentityBanner extends StatelessWidget {
  const ChurchIdentityBanner({
    required this.churchName,
    required this.primaryColor,
    this.secondaryColor,
    this.logoUrl,
    this.subtitle,
    this.action,
    super.key,
  });

  final String churchName;
  final String? logoUrl;
  final String? subtitle;
  final Color primaryColor;
  final Color? secondaryColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary =
        secondaryColor ?? Color.lerp(primaryColor, Colors.white, 0.28)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [primaryColor, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.88),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              backgroundImage: logoUrl?.trim().isNotEmpty == true
                  ? NetworkImage(logoUrl!)
                  : null,
              child: logoUrl?.trim().isNotEmpty == true
                  ? null
                  : const Icon(Icons.church_outlined, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  churchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? 'Seja bem-vindo a casa de Deus.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            action!,
          ],
        ],
      ),
    );
  }
}
