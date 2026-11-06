import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/provider_state.dart';
import '../widgets/provider_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<ProviderState>(context, listen: false);
      _searchController.text = state.searchQuery;
      state.searchProviders(resetPage: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal(BuildContext context) {
    final state = Provider.of<ProviderState>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Providers',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          state.resetFilters();
                          _searchController.clear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // City Selector
                  const Text('City', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: state.selectedCity ?? 'All Cities',
                    items: AppConstants.pakistaniCities.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      state.selectCity(val);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Min Rating
                  const Text('Minimum Rating', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [0.0, 3.0, 4.0, 4.5].map((r) {
                      final isSelected = state.minRating == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(r == 0.0 ? 'Any' : '$r+ ★'),
                          selected: isSelected,
                          onSelected: (_) {
                            state.setMinRating(r);
                            setModalState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Verified Only Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified Providers Only',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Only show providers approved by KaamConnect admin'),
                    value: state.verifiedOnly == true,
                    activeColor: AppConstants.verifiedGreen,
                    onChanged: (val) {
                      state.setVerifiedOnly(val ? true : null);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sort
                  const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _sortChip('Highest Rating', 'rating', state, setModalState),
                      const SizedBox(width: 8),
                      _sortChip('Newest', 'newest', state, setModalState),
                      const SizedBox(width: 8),
                      _sortChip('Name', 'name', state, setModalState),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortChip(
      String label, String value, ProviderState state, StateSetter setModalState) {
    final isSelected = state.sort == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        state.setSort(value);
        setModalState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<ProviderState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Local Services'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.selectedCity != null ||
                  state.selectedCategorySlug != null ||
                  state.minRating > 0 ||
                  state.verifiedOnly == true,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter',
            onPressed: () => _showFilterModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by keyword or service...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          state.setSearchQuery('');
                          state.searchProviders(resetPage: true);
                        },
                      )
                    : null,
              ),
              onSubmitted: (query) {
                state.setSearchQuery(query);
                state.searchProviders(resetPage: true);
              },
            ),
          ),

          // Horizontal Category Chips
          if (state.categories.isNotEmpty) ...[
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isAll = state.selectedCategorySlug == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('All Categories'),
                        selected: isAll,
                        onSelected: (_) => state.selectCategory(null),
                      ),
                    );
                  }
                  final cat = state.categories[index - 1];
                  final isSelected = state.selectedCategorySlug == cat.slug;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(cat.iconData, size: 16),
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (_) => state.selectCategory(cat.slug),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Active filter pills
          if (state.selectedCity != null ||
              state.verifiedOnly == true ||
              state.minRating > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  if (state.selectedCity != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(state.selectedCity!),
                        onDeleted: () => state.selectCity(null),
                      ),
                    ),
                  if (state.verifiedOnly == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: const Text('Verified Only'),
                        onDeleted: () => state.setVerifiedOnly(null),
                      ),
                    ),
                  if (state.minRating > 0)
                    InputChip(
                      label: Text('${state.minRating}★+'),
                      onDeleted: () => state.setMinRating(0.0),
                    ),
                ],
              ),
            ),
          ],

          // Results Count & Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.searchResults.length} pros found',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Sorted by ${state.sort}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // Provider List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => state.searchProviders(resetPage: true),
              child: state.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : state.searchError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(state.searchError!),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => state.searchProviders(resetPage: true),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : state.searchResults.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded,
                                        size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No service providers found',
                                      style: TextStyle(
                                          fontSize: 17, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Try adjusting your search query, city, or filters.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        state.resetFilters();
                                      },
                                      child: const Text('Clear All Filters'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              itemCount: state.searchResults.length,
                              itemBuilder: (context, index) {
                                return ProviderCard(
                                    provider: state.searchResults[index]);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
