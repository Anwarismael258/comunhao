import 'package:flutter/material.dart';

class ExpandableProfileAvatar extends StatelessWidget {
  const ExpandableProfileAvatar({
    required this.avatarUrl,
    required this.label,
    this.radius = 20,
    this.fallbackIcon = Icons.person_outline,
    this.backgroundColor,
    super.key,
  });

  final String? avatarUrl;
  final String label;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: hasImage ? null : Icon(fallbackIcon, size: radius),
    );

    return Tooltip(
      message: hasImage ? 'Ver foto' : label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: hasImage ? () => _openPhoto(context, url, label) : null,
        child: avatar,
      ),
    );
  }

  static Future<void> _openPhoto(
    BuildContext context,
    String imageUrl,
    String label,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  label.isEmpty ? 'Foto de perfil' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 220,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
