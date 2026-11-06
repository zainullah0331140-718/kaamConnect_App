import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/provider_state.dart';
import '../widgets/app_logo.dart';
import '../widgets/category_card.dart';
import '../widgets/provider_card.dart';
import 'server_config_dialog.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onTabChange;

  const HomeScreen({
    super.key,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ProviderState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 32, borderRadius: 8),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Trusted Local Pros',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Server Connection Settings',
            onPressed: () async {
              final changed = await showDialog<bool>(
                context: context,
                builder: (_) => const ServerConfigDialog(),
              );
              if (changed == true && context.mounted) {
                state.fetchHomeData();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.fetchHomeData(),
        child: state.isHomeLoading
            ? const Center(child: CircularProgressIndicator())
            : state.homeError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 56, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not connect to KaamConnect Backend',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.homeError!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.settings),
                                label: const Text('Server URL'),
                                onPressed: () async {
                                  final changed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => const ServerConfigDialog(),
                                  );
                                  if (changed == true && context.mounted) {
                                    state.fetchHomeData();
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                onPressed: () => state.fetchHomeData(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar teaser
                        GestureDetector(
                          onTap: () {
                            onTabChange(1); // switch to Explore tab
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: AppConstants.primaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Search electrician, plumber, carpenter...',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.tune,
                                    color: AppConstants.primaryColor,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Promotional Ads Banner
                        const SizedBox(height: 16),
                        if (state.advertisements.isNotEmpty) ...[
                          SizedBox(
                            height: 145,
                            child: PageView.builder(
                              itemCount: state.advertisements.length,
                              itemBuilder: (context, index) {
                                final ad = state.advertisements[index];
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  color: AppConstants.primaryColor,
                                  child: InkWell(
                                    onTap: () async {
                                      if (ad.destinationUrl.isNotEmpty) {
                                        final uri = Uri.tryParse(ad.destinationUrl);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        if (ad.imagePath.isNotEmpty)
                                          Positioned.fill(
                                            child: Image.network(
                                              ApiClient().getMediaUrl(ad.imagePath),
                                              fit: BoxFit.cover,
                                              color: Colors.black.withOpacity(0.4),
                                              colorBlendMode: BlendMode.darken,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [AppConstants.primaryColor, AppConstants.primaryDark],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants.secondaryColor,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'FEATURED AD',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (ad.destinationUrl.isNotEmpty)
                                                    const Icon(Icons.open_in_new, color: Colors.white70, size: 16),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                ad.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                ad.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppConstants.secondaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'GROW YOUR BUSINESS',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Advertise with KaamConnect',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Promote your skills & products directly on this home banner.',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.campaign_rounded, color: Colors.white70, size: 48),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Categories Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Service Categories',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () => onTabChange(1),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (state.categories.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No categories loaded yet'),
                            ),
                          )
                        else
                          SizedBox(
                            height: 115,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: state.categories.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = state.categories[index];
                                return CategoryCard(
                                  category: cat,
                                  onTap: () {
                                    state.selectCategory(cat.slug);
                                    onTabChange(1); // Jump to explore
                                  },
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Featured Verified Providers Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Top Rated Providers',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.verified, color: AppConstants.verifiedGreen, size: 18),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                state.setVerifiedOnly(true);
                                onTabChange(1);
                              },
                              child: const Text('See More'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        if (state.featuredProviders.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No verified providers found. Seed database or register!',
                                  style: TextStyle(color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.featuredProviders.length,
                            itemBuilder: (context, index) {
                              return ProviderCard(provider: state.featuredProviders[index]);
                            },
                          ),

                        const SizedBox(height: 24),

                        // Recent Providers Section
                        if (state.recentProviders.isNotEmpty) ...[
                          const Text(
                            'Newly Joined Professionals',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.recentProviders.length,
                            itemBuilder: (context, index) {
                              return ProviderCard(provider: state.recentProviders[index]);
                            },
                          ),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }
}
