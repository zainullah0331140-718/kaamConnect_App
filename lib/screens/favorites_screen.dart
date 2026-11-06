import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/provider_card.dart';
import 'login_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const FavoritesScreen({
    super.key,
    required this.onTabChange,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<FavoritesProvider>(context, listen: false).fetchFavorites();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final favState = Provider.of<FavoritesProvider>(context);

    final hasFavorites = favState.favorites.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Saved Providers'),
            if (hasFavorites)
              Text(
                '${favState.favorites.length} provider${favState.favorites.length != 1 ? 's' : ''} saved',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.isAuthenticated) {
            await favState.fetchFavorites();
          }
        },
        child: favState.isLoading && !hasFavorites
            ? const Center(child: CircularProgressIndicator())
            : !hasFavorites
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_border_rounded,
                              size: 56,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            auth.isAuthenticated ? 'No Saved Providers Yet' : 'Save Your Favorite Providers',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            auth.isAuthenticated
                                ? 'Tap the heart icon on any provider profile or card to save them here for quick access.'
                                : 'Save trusted plumbers, electricians, and technicians for quick future contact, even while offline.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.search, size: 18),
                                label: const Text('Explore Providers'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                onPressed: () => widget.onTabChange(1), // Go to search / explore tab
                              ),
                              if (!auth.isAuthenticated) ...[
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.login, size: 18),
                                  label: const Text('Log In'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: favState.favorites.length + (!auth.isAuthenticated ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (!auth.isAuthenticated && index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_sync_outlined, color: AppConstants.primaryColor, size: 22),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Saved on this device. Log in to sync across all your devices.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  );
                                },
                                child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }

                      final itemIndex = !auth.isAuthenticated ? index - 1 : index;
                      final provider = favState.favorites[itemIndex];
                      return ProviderCard(provider: provider);
                    },
                  ),
      ),
    );
  }
}
