import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/provider_state.dart';
import '../widgets/rating_stars.dart';
import '../widgets/verified_badge.dart';
import 'add_complaint_dialog.dart';
import 'add_review_dialog.dart';

class ProviderDetailScreen extends StatefulWidget {
  final int providerId;

  const ProviderDetailScreen({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProviderState>(context, listen: false)
          .fetchProviderDetail(widget.providerId);
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $urlString'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ProviderState>(context);
    final auth = Provider.of<AuthProvider>(context);
    final favorites = Provider.of<FavoritesProvider>(context);

    final provider = state.selectedProvider;
    final isFav = provider != null
        ? (favorites.isFavorite(provider.id) || provider.isFavorite)
        : false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(provider?.businessName ?? 'Provider Details'),
        actions: [
          if (provider != null)
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? Colors.red : null,
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
      body: state.isDetailLoading
          ? const Center(child: CircularProgressIndicator())
          : state.detailError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(state.detailError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => state.fetchProviderDetail(widget.providerId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : provider == null
                  ? const Center(child: Text('Provider not found'))
                  : RefreshIndicator(
                      onRefresh: () => state.fetchProviderDetail(widget.providerId),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: AppConstants.primaryColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(16),
                                            image: provider.profileImage != null &&
                                                    provider.profileImage!.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(ApiClient()
                                                        .getMediaUrl(provider.profileImage)),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: provider.profileImage == null ||
                                                  provider.profileImage!.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    provider.businessName.isNotEmpty
                                                        ? provider.businessName
                                                            .substring(0, 1)
                                                            .toUpperCase()
                                                        : 'K',
                                                    style: const TextStyle(
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppConstants.primaryColor,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),

                                        // Name, verification, rating
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      provider.businessName,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                provider.providerName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              VerifiedBadge(
                                                  status: provider.verificationStatus),
                                              const SizedBox(height: 6),
                                              RatingStars(
                                                rating: provider.averageRating,
                                                reviewCount: provider.reviewCount,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 12),

                                    // Location, Experience, Address Info
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _infoItem(
                                          icon: Icons.location_on_outlined,
                                          title: 'City / Area',
                                          value: provider.locationString,
                                        ),
                                        _infoItem(
                                          icon: Icons.work_history_outlined,
                                          title: 'Experience',
                                          value: provider.experienceYears > 0
                                              ? '${provider.experienceYears} Years'
                                              : 'Established',
                                        ),
                                        _infoItem(
                                          icon: Icons.rate_review_outlined,
                                          title: 'Reviews',
                                          value: '${provider.reviewCount}',
                                        ),
                                      ],
                                    ),

                                    if (provider.description != null &&
                                        provider.description!.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'About Business',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        provider.description!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Contact Action Buttons (Call / WhatsApp)
                            Row(
                              children: [
                                if (provider.contactPhone != null &&
                                    provider.contactPhone!.isNotEmpty) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      icon: const Icon(Icons.phone),
                                      label: const Text('Call Now'),
                                      onPressed: () {
                                        _launchUrl('tel:${provider.contactPhone}');
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                if (provider.whatsappNumber != null &&
                                    provider.whatsappNumber!.isNotEmpty) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      label: const Text('WhatsApp'),
                                      onPressed: () {
                                        final cleanNum = provider.whatsappNumber!
                                            .replaceAll(RegExp(r'[^0-9]'), '');
                                        _launchUrl('https://wa.me/$cleanNum');
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Services Offered
                            const Text(
                              'Services & Rates',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            if (provider.services.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'No services listed yet.',
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: provider.services.length,
                                itemBuilder: (context, index) {
                                  final s = provider.services[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(
                                        s.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: s.description != null && s.description!.isNotEmpty
                                          ? Text(s.description!)
                                          : (s.categoryName != null ? Text(s.categoryName!) : null),
                                      trailing: Text(
                                        s.formattedPrice,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // Work Images Gallery
                            if (provider.workImages.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Text(
                                'Work Portfolio',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: provider.workImages.length,
                                  itemBuilder: (context, index) {
                                    final img = provider.workImages[index];
                                    return Container(
                                      width: 120,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              ApiClient().getMediaUrl(img.imagePath)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Reviews & Feedback
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Customer Reviews',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                                  label: const Text('Add Review'),
                                  onPressed: () async {
                                    if (!auth.isAuthenticated) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please log in to write a review'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }
                                    final added = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AddReviewDialog(
                                        providerId: provider.id,
                                        providerName: provider.businessName,
                                      ),
                                    );
                                    if (added == true) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Review submitted successfully!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (state.providerReviews.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.star_outline,
                                            size: 36, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No reviews yet. Be the first to review!',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.providerReviews.length,
                                itemBuilder: (context, index) {
                                  final r = state.providerReviews[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                r.customerName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                DateFormat.yMMMd().format(r.createdAt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          RatingStars(
                                              rating: r.rating.toDouble(), size: 14),
                                          if (r.comment != null &&
                                              r.comment!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              r.comment!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.grey.shade300
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 24),

                            // Report Provider button
                            Center(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.report_outlined, size: 18),
                                label: const Text('Report or File a Complaint'),
                                onPressed: () async {
                                  if (!auth.isAuthenticated) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please log in to submit a complaint'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  final filed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AddComplaintDialog(
                                      providerId: provider.id,
                                      providerName: provider.businessName,
                                    ),
                                  );
                                  if (filed == true) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Complaint submitted to KaamConnect support.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppConstants.primaryColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
