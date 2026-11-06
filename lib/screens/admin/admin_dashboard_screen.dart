import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/category_model.dart';
import '../../providers/provider_state.dart';
import '../../widgets/verified_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  Map<String, dynamic>? _stats;

  // Verifications
  bool _loadingProviders = false;
  List<dynamic> _providers = [];
  String _providerStatusFilter = 'all'; // 'all', 'pending', 'verified', 'rejected'

  // Advertisements
  bool _loadingAds = false;
  List<dynamic> _ads = [];
  String _adStatusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  // Categories
  bool _loadingCategories = false;
  List<CategoryModel> _categories = [];

  static final List<Map<String, dynamic>> _defaultIconOptions = [
    {'key': 'tools', 'label': 'General Tools & Repairs', 'icon': Icons.handyman},
    {'key': 'lightning-charge', 'label': 'Electrician & Power', 'icon': Icons.electrical_services},
    {'key': 'droplet', 'label': 'Plumbing & Drainage', 'icon': Icons.plumbing},
    {'key': 'hammer', 'label': 'Carpentry & Woodwork', 'icon': Icons.carpenter},
    {'key': 'brush', 'label': 'Painting & Polishing', 'icon': Icons.format_paint},
    {'key': 'snow', 'label': 'AC & Refrigeration', 'icon': Icons.ac_unit},
    {'key': 'laptop', 'label': 'Computer & Laptop Repair', 'icon': Icons.laptop_chromebook},
    {'key': 'phone', 'label': 'Mobile Phone Repair', 'icon': Icons.phone_android},
    {'key': 'camera', 'label': 'CCTV & Security Systems', 'icon': Icons.videocam},
    {'key': 'solar', 'label': 'Solar Panel Installation', 'icon': Icons.solar_power},
    {'key': 'car', 'label': 'Auto Mechanic & Vehicle', 'icon': Icons.directions_car},
    {'key': 'cleaning', 'label': 'Cleaning & Housekeeping', 'icon': Icons.cleaning_services},
    {'key': 'pest', 'label': 'Pest Control', 'icon': Icons.pest_control},
    {'key': 'garden', 'label': 'Gardening & Lawn', 'icon': Icons.yard},
  ];

  // Reviews
  bool _loadingReviews = false;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Safely load all initial data after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadStats(),
      _loadProviders(),
      _loadAds(),
      _loadCategories(),
      _loadReviews(),
    ]);
  }

  Future<void> _loadStats() async {
    try {
      final res = await _api.get('/admin/stats', authenticated: true);
      if (res is Map<String, dynamic> && mounted) {
        setState(() => _stats = res);
      }
    } catch (_) {}
  }

  // 1. Providers Verification
  Future<void> _loadProviders() async {
    if (!mounted) return;
    setState(() => _loadingProviders = true);
    try {
      final queryParams = <String, String>{
        'page': '1',
        'page_size': '50',
      };
      if (_providerStatusFilter != 'all') {
        queryParams['status'] = _providerStatusFilter;
      }

      final res = await _api.get(
        '/admin/providers',
        authenticated: true,
        queryParams: queryParams,
      );
      if (res is Map && res['items'] is List && mounted) {
        setState(() => _providers = res['items']);
      }
    } catch (e) {
      _showSnack('Failed to load providers: $e');
    }
    if (mounted) setState(() => _loadingProviders = false);
  }

  Future<void> _setProviderVerification(int providerId, String status) async {
    final noteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status == 'verified' ? 'Verify' : 'Reject'} Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change provider verification status to: ${status.toUpperCase()}'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Note (Optional)',
                hintText: 'Reason or instructions...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'verified' ? AppConstants.verifiedGreen : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm $status'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.patch(
          '/admin/providers/$providerId/verification',
          authenticated: true,
          body: {
            'status': status,
            'note': noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
          },
        );
        _showSnack('Provider $status successfully!');
        _loadProviders();
        _loadStats();
      } catch (e) {
        _showSnack('Error: $e');
      }
    }
  }

  // 2. Advertisements Moderation
  Future<void> _loadAds() async {
    if (!mounted) return;
    setState(() => _loadingAds = true);
    try {
      final queryParams = <String, String>{
        'page': '1',
        'page_size': '50',
      };
      if (_adStatusFilter != 'all') {
        queryParams['status'] = _adStatusFilter;
      }

      final res = await _api.get(
        '/admin/advertisements',
        authenticated: true,
        queryParams: queryParams,
      );
      if (res is Map && res['items'] is List && mounted) {
        setState(() => _ads = res['items']);
      }
    } catch (e) {
      _showSnack('Failed to load advertisements: $e');
    }
    if (mounted) setState(() => _loadingAds = false);
  }

  Future<void> _moderateAd(int adId, String newStatus) async {
    final noteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newStatus == 'approved' ? 'Approve' : 'Reject'} Advertisement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to mark this ad as ${newStatus.toUpperCase()}?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Note (Optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'approved' ? AppConstants.verifiedGreen : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm $newStatus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.patch(
          '/admin/advertisements/$adId',
          authenticated: true,
          body: {
            'status': newStatus,
            'note': noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
          },
        );
        _showSnack('Advertisement $newStatus!');
        _loadAds();
        _loadStats();
      } catch (e) {
        _showSnack('Error: $e');
      }
    }
  }

  // 3. Categories Management
  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _loadingCategories = true);
    try {
      dynamic res;
      try {
        res = await _api.get('/admin/categories', authenticated: true);
      } catch (_) {
        // Fallback to public categories if admin route throws
        res = await _api.get('/categories');
      }

      if (res is List && mounted) {
        setState(() {
          _categories = res.map((e) => CategoryModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      _showSnack('Failed to load categories: $e');
    }
    if (mounted) setState(() => _loadingCategories = false);
  }

  Future<void> _showAddCategoryDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final descController = TextEditingController();
    final iconOptions = List<Map<String, dynamic>>.from(_defaultIconOptions);

    String selectedIcon = 'tools';
    bool isSubmitting = false;
    String? dialogError;

    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.category_rounded, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('Add New Category'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a new service category for providers & customers.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),

                      // Name
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. CCTV & Security',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        onChanged: (val) {
                          // Auto generate slug
                          final clean = val
                              .trim()
                              .toLowerCase()
                              .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                              .replaceAll(RegExp(r'^-+|-+$'), '');
                          slugController.text = clean;
                        },
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Name must be at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Slug
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(
                          labelText: 'Slug (URL identifier)',
                          hintText: 'e.g. cctv-security',
                          prefixIcon: Icon(Icons.link),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter a slug';
                          if (!RegExp(r'^[a-z0-9-]+$').hasMatch(val.trim())) {
                            return 'Only lowercase letters, numbers, and hyphens allowed';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Icon Selector Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedIcon,
                        decoration: const InputDecoration(
                          labelText: 'Category Icon',
                          prefixIcon: Icon(Icons.interests_outlined),
                        ),
                        items: iconOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['key'] as String,
                            child: Row(
                              children: [
                                Icon(opt['icon'] as IconData, size: 20, color: AppConstants.primaryColor),
                                const SizedBox(width: 10),
                                Text(
                                  opt['label'] as String,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedIcon = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Describe services included in this category...',
                        ),
                      ),

                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            dialogError!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          try {
                            final slug = slugController.text.trim().toLowerCase();
                            final body = {
                              'name': nameController.text.trim(),
                              'slug': slug,
                              'icon': selectedIcon,
                              'description': descController.text.trim().isNotEmpty
                                  ? descController.text.trim()
                                  : null,
                              'is_active': true,
                            };

                            await _api.post(
                              '/admin/categories',
                              authenticated: true,
                              body: body,
                            );

                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDlgState(() {
                              isSubmitting = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Category'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true) {
      _showSnack('Category created successfully!');
      _loadCategories();
      _loadStats();
      // Also notify global ProviderState so Explore & Home screens see the new category
      if (mounted) {
        Provider.of<ProviderState>(context, listen: false).fetchHomeData();
      }
    }
  }

  Future<void> _showEditCategoryDialog(CategoryModel category) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category.name);
    final slugController = TextEditingController(text: category.slug);
    final descController = TextEditingController(text: category.description ?? '');

    final iconOptions = List<Map<String, dynamic>>.from(_defaultIconOptions);
    if (category.icon != null &&
        category.icon!.isNotEmpty &&
        !iconOptions.any((o) => o['key'] == category.icon)) {
      iconOptions.add({
        'key': category.icon!,
        'label': category.icon!,
        'icon': Icons.category,
      });
    }

    String selectedIcon = category.icon != null && iconOptions.any((o) => o['key'] == category.icon)
        ? category.icon!
        : 'tools';
    bool isActive = category.isActive;
    bool isSubmitting = false;
    String? dialogError;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppConstants.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Category (${category.name})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category ID: ${category.id} | ${category.providerCount} active providers',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),

                      // Name
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Name must be at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Slug
                      TextFormField(
                        controller: slugController,
                        decoration: InputDecoration(
                          labelText: 'Slug (URL identifier)',
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.auto_fix_high, size: 18),
                            tooltip: 'Regenerate slug from name',
                            onPressed: () {
                              final clean = nameController.text
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                                  .replaceAll(RegExp(r'^-+|-+$'), '');
                              slugController.text = clean;
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter a slug';
                          if (!RegExp(r'^[a-z0-9-]+$').hasMatch(val.trim())) {
                            return 'Only lowercase letters, numbers, and hyphens allowed';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Icon Selector Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedIcon,
                        decoration: const InputDecoration(
                          labelText: 'Category Icon',
                          prefixIcon: Icon(Icons.interests_outlined),
                        ),
                        items: iconOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['key'] as String,
                            child: Row(
                              children: [
                                Icon(opt['icon'] as IconData, size: 20, color: AppConstants.primaryColor),
                                const SizedBox(width: 10),
                                Text(
                                  opt['label'] as String,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedIcon = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Describe services included in this category...',
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Active Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Is Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Active categories appear in search and home screens', style: TextStyle(fontSize: 12)),
                        value: isActive,
                        activeColor: AppConstants.primaryColor,
                        onChanged: (val) => setDlgState(() => isActive = val),
                      ),

                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            dialogError!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          try {
                            final slug = slugController.text.trim().toLowerCase();
                            final body = {
                              'name': nameController.text.trim(),
                              'slug': slug,
                              'icon': selectedIcon,
                              'description': descController.text.trim().isNotEmpty
                                  ? descController.text.trim()
                                  : null,
                              'is_active': isActive,
                            };

                            await _api.patch(
                              '/admin/categories/${category.id}',
                              authenticated: true,
                              body: body,
                            );

                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDlgState(() {
                              isSubmitting = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      _showSnack('Category updated successfully!');
      _loadCategories();
      _loadStats();
      if (mounted) {
        Provider.of<ProviderState>(context, listen: false).fetchHomeData();
      }
    }
  }

  // 4. Reviews Moderation
  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() => _loadingReviews = true);
    try {
      final res = await _api.get(
        '/admin/reviews',
        authenticated: true,
        queryParams: {'status': 'pending', 'page': '1', 'page_size': '50'},
      );
      if (res is Map && res['items'] is List && mounted) {
        setState(() => _reviews = res['items']);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingReviews = false);
  }

  Future<void> _moderateReview(int reviewId, String status) async {
    try {
      await _api.patch(
        '/admin/reviews/$reviewId',
        authenticated: true,
        body: {'status': status},
      );
      _showSnack('Review marked as $status');
      _loadReviews();
      _loadStats();
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppConstants.primaryColor),
            SizedBox(width: 8),
            Text('KaamConnect Admin Panel'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All Data',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppConstants.primaryColor,
          indicatorColor: AppConstants.primaryColor,
          tabs: [
            Tab(
              text: 'Providers (${_stats?['pending_providers'] ?? 0} Pending)',
              icon: const Icon(Icons.verified_user_outlined),
            ),
            Tab(
              text: 'Ads (${_stats?['pending_ads'] ?? 0} Pending)',
              icon: const Icon(Icons.campaign_outlined),
            ),
            Tab(
              text: 'Categories (${_categories.length})',
              icon: const Icon(Icons.category_outlined),
            ),
            Tab(
              text: 'Reviews (${_stats?['pending_reviews'] ?? 0})',
              icon: const Icon(Icons.rate_review_outlined),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProvidersTab(),
          _buildAdsTab(),
          _buildCategoriesTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  // TAB 1: Providers
  Widget _buildProvidersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProviders();
        await _loadStats();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _providerStatusFilter == 'all',
                    onSelected: (_) {
                      setState(() => _providerStatusFilter = 'all');
                      _loadProviders();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Pending'),
                    selected: _providerStatusFilter == 'pending',
                    onSelected: (_) {
                      setState(() => _providerStatusFilter = 'pending');
                      _loadProviders();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Verified'),
                    selected: _providerStatusFilter == 'verified',
                    onSelected: (_) {
                      setState(() => _providerStatusFilter = 'verified');
                      _loadProviders();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Rejected'),
                    selected: _providerStatusFilter == 'rejected',
                    onSelected: (_) {
                      setState(() => _providerStatusFilter = 'rejected');
                      _loadProviders();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loadingProviders
                ? const Center(child: CircularProgressIndicator())
                : _providers.isEmpty
                    ? Center(
                        child: Text('No $_providerStatusFilter providers found.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _providers.length,
                        itemBuilder: (context, index) {
                          final p = _providers[index];
                          final id = p['id'];
                          final status = p['verification_status'] ?? 'pending';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['business_name'] ?? 'Provider',
                                          style: const TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      VerifiedBadge(status: status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Owner: ${p['provider_name']} (${p['email'] ?? 'No email'})',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                  Text(
                                    'Location: ${p['city'] ?? ''} - ${p['area'] ?? ''} | Phone: ${p['contact_phone'] ?? p['phone'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (status != 'verified')
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppConstants.verifiedGreen,
                                            minimumSize: const Size(100, 36),
                                          ),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('Verify'),
                                          onPressed: () => _setProviderVerification(id, 'verified'),
                                        ),
                                      const SizedBox(width: 8),
                                      if (status != 'rejected')
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            minimumSize: const Size(100, 36),
                                          ),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Reject'),
                                          onPressed: () => _setProviderVerification(id, 'rejected'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Advertisements
  Widget _buildAdsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadAds();
        await _loadStats();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ChoiceChip(
                    label: const Text('All Ads'),
                    selected: _adStatusFilter == 'all',
                    onSelected: (_) {
                      setState(() => _adStatusFilter = 'all');
                      _loadAds();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Pending'),
                    selected: _adStatusFilter == 'pending',
                    onSelected: (_) {
                      setState(() => _adStatusFilter = 'pending');
                      _loadAds();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Approved'),
                    selected: _adStatusFilter == 'approved',
                    onSelected: (_) {
                      setState(() => _adStatusFilter = 'approved');
                      _loadAds();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Rejected'),
                    selected: _adStatusFilter == 'rejected',
                    onSelected: (_) {
                      setState(() => _adStatusFilter = 'rejected');
                      _loadAds();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loadingAds
                ? const Center(child: CircularProgressIndicator())
                : _ads.isEmpty
                    ? Center(
                        child: Text(
                          _adStatusFilter == 'all'
                              ? 'No advertisements found in system.'
                              : 'No $_adStatusFilter advertisements.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _ads.length,
                        itemBuilder: (context, index) {
                          final ad = _ads[index];
                          final id = ad['id'];
                          final image = ad['image_path'] ?? '';
                          final status = ad['status'] ?? 'pending';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (image.isNotEmpty)
                                  SizedBox(
                                    height: 140,
                                    width: double.infinity,
                                    child: Image.network(
                                      _api.getMediaUrl(image),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: AppConstants.primaryColor.withOpacity(0.1),
                                        child: const Center(
                                          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ad['title'] ?? 'Advertisement',
                                              style: const TextStyle(
                                                  fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'approved'
                                                  ? Colors.green.shade100
                                                  : (status == 'pending'
                                                      ? Colors.amber.shade100
                                                      : Colors.red.shade100),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'approved'
                                                    ? Colors.green.shade800
                                                    : (status == 'pending'
                                                        ? Colors.amber.shade900
                                                        : Colors.red.shade800),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'By: ${ad['provider_name']} | Dates: ${ad['start_date']} to ${ad['end_date']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        ad['description'] ?? '',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (status != 'approved')
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppConstants.verifiedGreen,
                                                minimumSize: const Size(110, 36),
                                              ),
                                              icon: const Icon(Icons.check, size: 16),
                                              label: const Text('Approve Ad'),
                                              onPressed: () => _moderateAd(id, 'approved'),
                                            ),
                                          const SizedBox(width: 8),
                                          if (status != 'rejected')
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                                minimumSize: const Size(110, 36),
                                              ),
                                              icon: const Icon(Icons.close, size: 16),
                                              label: const Text('Reject Ad'),
                                              onPressed: () => _moderateAd(id, 'rejected'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Categories
  Widget _buildCategoriesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCategories();
        await _loadStats();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories (${_categories.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Services available in system',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(130, 40),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Category'),
                  onPressed: _showAddCategoryDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingCategories
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No categories found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Category'),
                              onPressed: _showAddCategoryDialog,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppConstants.primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(cat.iconData, color: AppConstants.primaryColor, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              cat.name,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                cat.slug,
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                              ),
                                            ),
                                            if (!cat.isActive) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'INACTIVE',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (cat.description != null && cat.description!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            cat.description!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          '${cat.providerCount} Active Provider${cat.providerCount != 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppConstants.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: AppConstants.primaryColor),
                                        tooltip: 'Edit Category',
                                        onPressed: () => _showEditCategoryDialog(cat),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'Delete Category',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Category'),
                                              content: Text('Are you sure you want to delete "${cat.name}"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            try {
                                              await _api.delete('/admin/categories/${cat.id}', authenticated: true);
                                              _showSnack('Category deleted successfully');
                                              _loadCategories();
                                              _loadStats();
                                              if (mounted) {
                                                Provider.of<ProviderState>(context, listen: false).fetchHomeData();
                                              }
                                            } catch (e) {
                                              _showSnack('Error: $e');
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // TAB 4: Reviews
  Widget _buildReviewsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadReviews();
        await _loadStats();
      },
      child: _loadingReviews
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? const Center(child: Text('No pending customer reviews to moderate.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) {
                    final r = _reviews[index];
                    final id = r['id'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${r['customer_name']} -> ${r['provider_name']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('${r['rating']} ★',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.secondaryColor)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(r['comment'] ?? 'No comment written.'),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.verifiedGreen,
                                    minimumSize: const Size(90, 34),
                                  ),
                                  onPressed: () => _moderateReview(id, 'approved'),
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    minimumSize: const Size(90, 34),
                                  ),
                                  onPressed: () => _moderateReview(id, 'rejected'),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
