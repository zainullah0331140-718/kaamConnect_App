import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/provider_model.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../screens/provider_detail_screen.dart';
import 'rating_stars.dart';
import 'verified_badge.dart';

class ProviderCard extends StatelessWidget {
  final ProviderSummary provider;

  const ProviderCard({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final favorites = Provider.of<FavoritesProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isFav = favorites.isFavorite(provider.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderDetailScreen(providerId: provider.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Avatar, Info, Favorite Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      image: provider.profileImage != null && provider.profileImage!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(ApiClient().getMediaUrl(provider.profileImage)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: provider.profileImage == null || provider.profileImage!.isEmpty
                        ? Center(
                            child: Text(
                              provider.businessName.isNotEmpty
                                  ? provider.businessName.substring(0, 1).toUpperCase()
                                  : 'K',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                provider.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            VerifiedBadge(status: provider.verificationStatus, compact: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RatingStars(
                          rating: provider.averageRating,
                          reviewCount: provider.reviewCount,
                          size: 14,
                        ),
                      ],
                    ),
                  ),

                  // Favorite toggle button
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.grey.shade400,
                      size: 22,
                    ),
                    tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                    onPressed: () async {
                      try {
                        final added = await favorites.toggleFavorite(provider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    added ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: added ? Colors.redAccent : Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      added
                                          ? (!auth.isAuthenticated
                                              ? 'Saved to favorites! Log in to sync.'
                                              : 'Added "${provider.businessName}" to favorites')
                                          : 'Removed "${provider.businessName}" from favorites',
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not update favorite: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Services chips preview
              if (provider.services.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: provider.services.take(3).map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Footer: Location & Starting Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        provider.locationString,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (provider.experienceYears > 0) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.work_history_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.experienceYears}y exp',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (provider.services.isNotEmpty && provider.services.first.priceMin != null) ...[
                    Text(
                      'From PKR ${provider.services.first.priceMin!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
