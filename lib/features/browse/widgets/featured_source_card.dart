import 'package:flutter/cupertino.dart';

import '../../../core/extensions/source_interface.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class FeaturedSourceCard extends StatelessWidget {
  const FeaturedSourceCard({
    super.key,
    required this.source,
    required this.onTap,
    required this.gradient,
  });

  final MangaSource source;
  final VoidCallback onTap;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle inner overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0x1AFFFFFF),
                      const Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(source.name, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${source.language.toUpperCase()} · ${source.baseUrl}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder card used when no real sources are installed yet.
class FeaturedSourcePlaceholderCard extends StatelessWidget {
  const FeaturedSourcePlaceholderCard({
    super.key,
    required this.name,
    required this.description,
    required this.gradient,
    this.onTap,
  });

  final String name;
  final String description;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(name, style: AppTextStyles.sectionTitle),
            const SizedBox(height: 4),
            Text(description, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
