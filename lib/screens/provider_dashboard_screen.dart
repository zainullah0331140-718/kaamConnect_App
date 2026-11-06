import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/category_model.dart';
import '../models/provider_model.dart';
import '../models/review_model.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/provider_state.dart';
import '../widgets/rating_stars.dart';
import '../widgets/verified_badge.dart';
import 'auth/delete_account_dialog.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _providerData;
  List<ServiceItem> _myServices = [];
  List<WorkImage> _workImages = [];
  List<dynamic> _myAds = [];
  List<ReviewModel> _myReviews = [];
  String? _reviewStatusFilter;

  bool _uploadingImage = false;
  bool _reviewsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Provider Profile Details
      try {
        final profileRes = await _api.get('/providers/me', authenticated: true);
        if (profileRes is Map) {
          _providerData = Map<String, dynamic>.from(profileRes);
          final rawWork = _providerData!['work_images'] as List? ?? [];
          _workImages = rawWork
              .map((img) => WorkImage.fromJson(Map<String, dynamic>.from(img as Map)))
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
        if (_providerData == null) {
          _error = 'Could not load provider profile: $e';
        }
      }

      // 2. Services
      try {
        final servicesRes = await _api.get('/provider-services/me', authenticated: true);
        if (servicesRes is List) {
          _myServices = servicesRes
              .map((s) => ServiceItem.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();
        } else if (servicesRes is Map && servicesRes['items'] is List) {
          _myServices = (servicesRes['items'] as List)
              .map((s) => ServiceItem.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading services: $e');
        // Fallback: check if _providerData already includes services
        if (_providerData != null && _providerData!['services'] is List) {
          final raw = _providerData!['services'] as List;
          _myServices = raw
              .map((s) => ServiceItem.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();
        }
      }

      // 3. Advertisements
      try {
        final adsRes = await _api.get('/advertisements/me', authenticated: true);
        if (adsRes is List) {
          _myAds = adsRes;
        } else if (adsRes is Map && adsRes['items'] is List) {
          _myAds = adsRes['items'];
        }
      } catch (e) {
        debugPrint('Error loading ads: $e');
      }

      // 4. Reviews received from customers
      await _loadReviews(status: _reviewStatusFilter);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReviews({String? status}) async {
    setState(() {
      _reviewStatusFilter = status;
      _reviewsLoading = true;
    });
    try {
      final res = await _api.get(
        '/reviews/provider/me',
        authenticated: true,
        queryParams: {
          'page_size': 100,
          'status': ?status,
        },
      );
      final items = res is Map && res['items'] is List
          ? res['items'] as List
          : res is List
              ? res
              : const [];
      if (!mounted) return;
      setState(() {
        _myReviews = items
            .map((r) => ReviewModel.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) {
        setState(() => _myReviews = []);
      }
    } finally {
      if (mounted) {
        setState(() => _reviewsLoading = false);
      }
    }
  }

  // --- 1. PROFILE PICTURE UPLOAD ---
  Future<void> _pickAndUploadProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _uploadingImage = true);

      await _api.uploadFile(
        '/providers/me/image',
        fileField: 'file',
        file: file,
      );

      if (!mounted) return;
      _showSnack('Profile picture updated successfully!');
      await Provider.of<AuthProvider>(context, listen: false)
          .fetchCurrentUser();
      _loadDashboardData();
    } catch (e) {
      _showSnack('Error uploading image: $e');
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  // --- 2. EDIT ACCOUNT / PROFILE DETAILS ---
  Future<void> _showEditProfileDialog() async {
    final formKey = GlobalKey<FormState>();
    final businessNameCtrl =
        TextEditingController(text: _providerData?['business_name'] ?? '');
    String selectedCity = _providerData?['city'] ?? 'Karachi';
    final areaCtrl = TextEditingController(text: _providerData?['area'] ?? '');
    final addressCtrl = TextEditingController(text: _providerData?['address'] ?? '');
    final expCtrl = TextEditingController(
        text: (_providerData?['experience_years'] ?? 0).toString());
    final descCtrl = TextEditingController(text: _providerData?['description'] ?? '');
    final phoneCtrl = TextEditingController(text: _providerData?['contact_phone'] ?? '');
    final waCtrl = TextEditingController(text: _providerData?['whatsapp_number'] ?? '');

    final cities = AppConstants.pakistaniCities
        .where((c) => c != 'All Cities')
        .toList();
    if (!cities.contains(selectedCity) && cities.isNotEmpty) {
      selectedCity = cities.first;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('Edit Business Profile'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: businessNameCtrl,
                        decoration: const InputDecoration(labelText: 'Business Name'),
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Name must be at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCity,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedCity = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: areaCtrl,
                        decoration: const InputDecoration(labelText: 'Area / Colony'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(labelText: 'Street Address'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: expCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Experience (Years)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: waCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'WhatsApp Number'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Business Description / Bio'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final body = {
                        'business_name': businessNameCtrl.text.trim(),
                        'city': selectedCity,
                        'area': areaCtrl.text.trim().isNotEmpty ? areaCtrl.text.trim() : null,
                        'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                        'experience_years': int.tryParse(expCtrl.text) ?? 0,
                        'contact_phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                        'whatsapp_number': waCtrl.text.trim().isNotEmpty ? waCtrl.text.trim() : null,
                        'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                      };
                      await _api.patch('/providers/me', body: body, authenticated: true);
                      if (context.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      _showSnack('Profile updated successfully!');
      _loadDashboardData();
    }
  }

  // --- 3. PRODUCT / WORK PHOTOS (UP TO 5 PHOTOS) ---
  Future<void> _pickAndUploadWorkPhotos() async {
    const maxPhotos = 5;
    final remaining = maxPhotos - _workImages.length;
    if (remaining <= 0) {
      _showSnack('Maximum 5 product/work photos allowed. Delete an existing photo first.');
      return;
    }

    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked.isEmpty) return;

      final toUpload = picked.take(remaining).toList();

      setState(() => _uploadingImage = true);

      await _api.uploadMultipleFiles(
        '/providers/me/work-images',
        filesField: 'files',
        files: toUpload,
      );

      _showSnack('Added ${toUpload.length} work/product photos successfully!');
      _loadDashboardData();
    } catch (e) {
      _showSnack('Error uploading photos: $e');
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _deleteWorkPhoto(int imageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to remove this work/product photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        await _api.delete('/providers/me/work-images/$imageId', authenticated: true);
        _showSnack('Photo removed!');
        _loadDashboardData();
      } catch (e) {
        _showSnack('Error: $e');
      }
    }
  }

  // --- 4. CREATE ADVERTISEMENT BANNER ---
  Future<void> _showCreateAdDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://kaamconnect.local');

    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));
    XFile? adBannerFile;
    Uint8List? adBannerBytes;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.campaign_rounded, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('Create Advertisement'),
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
                        'Promote your business on KaamConnect home banner. Admin will review and approve.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),

                      // Image picker box
                      GestureDetector(
                        onTap: () async {
                          final file = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            maxHeight: 600,
                          );
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            setDlgState(() {
                              adBannerFile = file;
                              adBannerBytes = bytes;
                            });
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: adBannerBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    adBannerBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green),
                                          const SizedBox(height: 4),
                                          Text(adBannerFile!.name, style: const TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                                      SizedBox(height: 6),
                                      Text('Select Banner Image (Required)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Headline / Title'),
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Title must be at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Ad Description / Offer'),
                        validator: (val) => val == null || val.trim().length < 10
                            ? 'Description must be at least 10 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(labelText: 'Destination Link / Website'),
                        validator: (val) => val == null || !val.startsWith('http')
                            ? 'Enter valid URL starting with http:// or https://'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setDlgState(() => startDate = d);
                              },
                              child: Text('Start: ${DateFormat.MMMd().format(startDate)}', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setDlgState(() => endDate = d);
                              },
                              child: Text('End: ${DateFormat.MMMd().format(endDate)}', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (adBannerFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a banner image for the ad')),
                      );
                      return;
                    }
                    if (!formKey.currentState!.validate()) return;

                    try {
                      final fields = {
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'destination_url': urlCtrl.text.trim(),
                        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                      };

                      await _api.uploadFile(
                        '/advertisements',
                        fileField: 'image',
                        file: adBannerFile!,
                        fields: fields,
                      );

                      if (context.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Submit Ad for Approval'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      _showSnack('Advertisement submitted! Admin will review and approve it.');
      _loadDashboardData();
    }
  }

  // --- 4b. EDIT ADVERTISEMENT BANNER ---
  Future<void> _showEditAdDialog(Map<String, dynamic> ad) async {
    final adId = ad['id'];
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: ad['title'] ?? '');
    final descCtrl = TextEditingController(text: ad['description'] ?? '');
    final urlCtrl = TextEditingController(
      text: (ad['destination_url'] ?? '').toString().isNotEmpty
          ? ad['destination_url']
          : 'https://kaamconnect.local',
    );

    DateTime startDate =
        DateTime.tryParse((ad['start_date'] ?? '').toString()) ?? DateTime.now();
    DateTime endDate = DateTime.tryParse((ad['end_date'] ?? '').toString()) ??
        DateTime.now().add(const Duration(days: 30));
    if (endDate.isBefore(DateTime.now())) {
      endDate = DateTime.now().add(const Duration(days: 30));
    }
    if (startDate.isAfter(endDate)) {
      startDate = DateTime.now();
    }
    final existingImage = (ad['image_path'] ?? '').toString();

    XFile? newBannerFile;
    Uint8List? newBannerBytes;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('Edit Advertisement'),
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
                        'Saving changes will send this ad back to admin for approval.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),

                      GestureDetector(
                        onTap: () async {
                          final file = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            maxHeight: 600,
                          );
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            setDlgState(() {
                              newBannerFile = file;
                              newBannerBytes = bytes;
                            });
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: newBannerBytes != null
                                ? Image.memory(newBannerBytes!, fit: BoxFit.cover)
                                : (existingImage.isNotEmpty
                                    ? Image.network(
                                        _api.getMediaUrl(existingImage),
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) =>
                                            const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                            size: 32,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate_outlined,
                                              size: 36,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              'Tap to choose a new banner (optional)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap the banner to replace it. Keep the current image if not needed.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ad Headline / Title',
                        ),
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Title must be at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ad Description / Offer',
                        ),
                        validator: (val) => val == null || val.trim().length < 10
                            ? 'Description must be at least 10 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Destination Link / Website',
                        ),
                        validator: (val) => val == null || !val.startsWith('http')
                            ? 'Enter valid URL starting with http:// or https://'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now()
                                      .subtract(const Duration(days: 3650)),
                                  lastDate:
                                      DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setDlgState(() => startDate = d);
                              },
                              child: Text(
                                'Start: ${DateFormat.MMMd().format(startDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: endDate.isBefore(startDate)
                                      ? startDate
                                      : endDate,
                                  firstDate: startDate,
                                  lastDate:
                                      DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setDlgState(() => endDate = d);
                              },
                              child: Text(
                                'End: ${DateFormat.MMMd().format(endDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      final body = {
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'destination_url': urlCtrl.text.trim(),
                        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                      };

                      await _api.patch(
                        '/advertisements/$adId',
                        body: body,
                        authenticated: true,
                      );

                      if (newBannerFile != null) {
                        await _api.uploadFile(
                          '/advertisements/$adId/image',
                          fileField: 'image',
                          file: newBannerFile!,
                        );
                      }

                      if (context.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      _showSnack('Advertisement updated and sent for approval.');
      _loadDashboardData();
    }
  }

  // --- 5. SERVICES MANAGEMENT ---
  Future<void> _showAddServiceDialog() async {
    final state = Provider.of<ProviderState>(context, listen: false);
    List<CategoryModel> categories = state.categories;

    if (categories.isEmpty) {
      try {
        final catRes = await _api.get('/categories');
        if (catRes is List) {
          categories = catRes
              .map((c) => CategoryModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (categories.isEmpty) {
      _showSnack('Please wait for categories to load, or check server connection');
      return;
    }

    final formKey = GlobalKey<FormState>();
    int? selectedCatId = categories.first.id;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final minPriceController = TextEditingController();
    final maxPriceController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('Add New Service'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedCatId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) => setDlgState(() => selectedCatId = val),
                        validator: (val) => val == null ? 'Select category' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Service Title',
                          hintText: 'e.g. Inverter AC Installation',
                          prefixIcon: Icon(Icons.handyman_outlined),
                        ),
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Title must be at least 2 chars'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Min Price (PKR)',
                                prefixText: 'Rs. ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Price (PKR)',
                                prefixText: 'Rs. ',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final body = {
                        'category_id': selectedCatId,
                        'title': titleController.text.trim(),
                        'description': descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                        'price_min': double.tryParse(minPriceController.text),
                        'price_max': double.tryParse(maxPriceController.text),
                        'is_active': true,
                      };
                      await _api.post('/provider-services', body: body, authenticated: true);
                      if (context.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  child: const Text('Create Service'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true) {
      _showSnack('Service added successfully!');
      _loadDashboardData();
    }
  }

  Future<void> _showEditServiceDialog(ServiceItem service) async {
    final state = Provider.of<ProviderState>(context, listen: false);
    List<CategoryModel> categories = state.categories;

    if (categories.isEmpty) {
      try {
        final catRes = await _api.get('/categories');
        if (catRes is List) {
          categories = catRes
              .map((c) => CategoryModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    int? selectedCatId = service.categoryId;
    if (!categories.any((c) => c.id == selectedCatId) && categories.isNotEmpty) {
      selectedCatId = categories.first.id;
    }

    final titleController = TextEditingController(text: service.title);
    final descController = TextEditingController(text: service.description ?? '');
    final minPriceController = TextEditingController(
      text: service.priceMin != null ? service.priceMin!.toStringAsFixed(0) : '',
    );
    final maxPriceController = TextEditingController(
      text: service.priceMax != null ? service.priceMax!.toStringAsFixed(0) : '',
    );
    bool isActive = service.isActive;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('Edit Service'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedCatId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) => setDlgState(() => selectedCatId = val),
                        validator: (val) => val == null ? 'Select category' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Service Title',
                          prefixIcon: Icon(Icons.handyman_outlined),
                        ),
                        validator: (val) => val == null || val.trim().length < 2
                            ? 'Title must be at least 2 chars'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Min Price (PKR)',
                                prefixText: 'Rs. ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Price (PKR)',
                                prefixText: 'Rs. ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Is Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Display this service on your public profile', style: TextStyle(fontSize: 12)),
                        value: isActive,
                        activeColor: AppConstants.primaryColor,
                        onChanged: (val) => setDlgState(() => isActive = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final body = {
                        'category_id': selectedCatId,
                        'title': titleController.text.trim(),
                        'description': descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                        'price_min': double.tryParse(minPriceController.text),
                        'price_max': double.tryParse(maxPriceController.text),
                        'is_active': isActive,
                      };
                      await _api.patch('/provider-services/${service.id}', body: body, authenticated: true);
                      if (context.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      _showSnack('Service updated successfully!');
      _loadDashboardData();
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
        title: const Text('Provider Business Portal'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          indicatorColor: AppConstants.primaryColor,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Profile & Photos', icon: Icon(Icons.person_pin_rounded)),
            Tab(text: 'Services (${_myServices.length})', icon: const Icon(Icons.handyman_outlined)),
            Tab(text: 'Ads (${_myAds.length})', icon: const Icon(Icons.campaign_outlined)),
            Tab(
              text: 'Reviews (${_providerData?['review_count'] ?? 0})',
              icon: const Icon(Icons.rate_review_outlined),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadDashboardData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileAndPhotosTab(),
                    _buildServicesTab(),
                    _buildAdsTab(),
                    _buildReviewsTab(),
                  ],
                ),
    );
  }

  // TAB 1: Profile & Product/Work Photos
  Widget _buildProfileAndPhotosTab() {
    final profileImg = _providerData?['profile_image'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Avatar + Camera Button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.primaryColor.withOpacity(0.15),
                        ),
                        child: ClipOval(
                          child: profileImg != null && profileImg.toString().isNotEmpty
                              ? Image.network(
                                  _api.getMediaUrl(profileImg.toString()),
                                  fit: BoxFit.cover,
                                  width: 76,
                                  height: 76,
                                  errorBuilder: (ctx, err, stack) => Center(
                                    child: Text(
                                      (_providerData?['business_name'] ?? 'P')[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.primaryColor,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (_providerData?['business_name'] ?? 'P')[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryColor,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingImage ? null : _pickAndUploadProfileImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppConstants.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: _uploadingImage
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _providerData?['business_name'] ?? 'My Business',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_providerData?['city'] ?? ''} - ${_providerData?['area'] ?? ''}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        VerifiedBadge(status: _providerData?['verification_status'] ?? 'pending'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Account Details & Edit Button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Account'),
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
                  const Divider(),
                  _detailRow('Business Name', _providerData?['business_name'] ?? 'N/A'),
                  _detailRow('City', _providerData?['city'] ?? 'N/A'),
                  _detailRow('Area', _providerData?['area'] ?? 'Not set'),
                  _detailRow('Address', _providerData?['address'] ?? 'Not set'),
                  _detailRow('Experience', '${_providerData?['experience_years'] ?? 0} Years'),
                  _detailRow('Contact Phone', _providerData?['contact_phone'] ?? 'Not set'),
                  _detailRow('WhatsApp', _providerData?['whatsapp_number'] ?? 'Not set'),
                  if (_providerData?['description'] != null) ...[
                    const SizedBox(height: 8),
                    const Text('Bio / Description:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(_providerData!['description']),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // PRODUCT / WORK PORTFOLIO PHOTOS (UP TO 5 PHOTOS)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Work & Product Photos (${_workImages.length} / 5)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_workImages.length < 5)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(120, 36),
                  ),
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: const Text('Add Photos'),
                  onPressed: _uploadingImage ? null : _pickAndUploadWorkPhotos,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upload up to 5 photos showcasing your completed jobs, equipment, and products.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          if (_workImages.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('No work/product photos uploaded yet.'),
                      const SizedBox(height: 4),
                      Text(
                        'Customers book 3x more providers with work photos!',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _workImages.length,
              itemBuilder: (context, index) {
                final img = _workImages[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _api.getMediaUrl(img.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _deleteWorkPhoto(img.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 20),

          // DANGER ZONE: DELETE PROVIDER ACCOUNT
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_forever_rounded,
                          color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Delete Business Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Permanently delete your KaamConnect account along with your business profile, services, advertisements and uploaded photos. This cannot be undone.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: const Text('Delete My Account'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final deleted = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              const DeleteAccountDialog(isProvider: true),
                        );
                        if (deleted == true && context.mounted) {
                          await Provider.of<FavoritesProvider>(context,
                                  listen: false)
                              .clearOnLogout();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Your account has been deleted.'),
                            ),
                          );
                          navigator.popUntil((route) => route.isFirst);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // TAB 2: Services
  Widget _buildServicesTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Services (${_myServices.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Pricing and service options shown to customers',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(120, 38),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Service'),
                  onPressed: _showAddServiceDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_myServices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.handyman_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'No services added yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap "Add Service" above to add your price list and skills.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Service'),
                          onPressed: _showAddServiceDialog,
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
                itemCount: _myServices.length,
                itemBuilder: (context, index) {
                  final s = _myServices[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (s.categoryName != null && s.categoryName!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppConstants.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s.categoryName!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    Text(
                                      s.title,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.formattedPrice,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (s.description != null && s.description!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        s.description!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppConstants.primaryColor),
                                    tooltip: 'Edit Service',
                                    onPressed: () => _showEditServiceDialog(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Delete Service',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Service'),
                                          content: Text('Are you sure you want to delete "${s.title}"?'),
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
                                          await _api.delete('/provider-services/${s.id}', authenticated: true);
                                          _showSnack('Service deleted');
                                          _loadDashboardData();
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
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // TAB 3: Advertisements (ads bi laga saky)
  Widget _buildAdsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Advertisements (${_myAds.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Promote your business on home banner',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(130, 38),
                  ),
                  icon: const Icon(Icons.add_photo_alternate, size: 16),
                  label: const Text('Create New Ad'),
                  onPressed: _showCreateAdDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_myAds.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'No advertisements created yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap "Create New Ad" above to publish your first banner promotion.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create Your First Ad'),
                          onPressed: _showCreateAdDialog,
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
                itemCount: _myAds.length,
                itemBuilder: (context, index) {
                  final ad = _myAds[index];
                  final id = ad['id'];
                  final image = ad['image_path'] ?? '';
                  final status = ad['status'] ?? 'pending';
                  final title = ad['title'] ?? 'Advertisement';
                  final desc = ad['description'] ?? '';
                  final startDate = ad['start_date'] ?? '';
                  final endDate = ad['end_date'] ?? '';
                  final adminNote = ad['admin_note'];
                  final destUrl = ad['destination_url'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (image.toString().isNotEmpty)
                          SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: Image.network(
                              _api.getMediaUrl(image.toString()),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                height: 140,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.campaign_outlined, size: 36, color: Colors.grey),
                                      SizedBox(height: 4),
                                      Text('Ad Banner Image', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Dates: $startDate to $endDate',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              if (destUrl.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.link, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        destUrl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(desc, style: const TextStyle(fontSize: 13)),
                              ],
                              if (adminNote != null && adminNote.toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Admin Note: $adminNote',
                                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppConstants.primaryColor,
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Edit Ad'),
                                    onPressed: () => _showEditAdDialog(
                                      Map<String, dynamic>.from(ad as Map),
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Delete Ad'),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Advertisement'),
                                          content: Text(
                                              'Are you sure you want to delete "$title"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        try {
                                          await _api.delete(
                                            '/advertisements/$id',
                                            authenticated: true,
                                          );
                                          _showSnack('Ad deleted successfully');
                                          _loadDashboardData();
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
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // TAB 4: Customer Reviews
  Widget _buildReviewsTab() {
    final avgRating = _providerData?['average_rating'] is num
        ? (_providerData!['average_rating'] as num).toDouble()
        : double.tryParse('${_providerData?['average_rating'] ?? 0}') ?? 0.0;
    final totalReviews = _providerData?['review_count'] is int
        ? _providerData!['review_count'] as int
        : int.tryParse('${_providerData?['review_count'] ?? 0}') ?? 0;

    return RefreshIndicator(
      onRefresh: () => _loadReviews(status: _reviewStatusFilter),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        avgRating > 0 ? avgRating.toStringAsFixed(1) : '-',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RatingStars(
                        rating: avgRating,
                        showText: false,
                        size: 16,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalReviews review${totalReviews == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      totalReviews == 0
                          ? 'No reviews yet. Customers can review your business after using your services.'
                          : 'Approved reviews appear on your public profile and help customers trust your business.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Customer Reviews',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_reviewsLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _reviewFilterChip('All', null),
                _reviewFilterChip('Approved', 'approved'),
                _reviewFilterChip('Pending', 'pending'),
                _reviewFilterChip('Rejected', 'rejected'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_reviewsLoading && _myReviews.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 44,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No reviews in this category',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reviews submitted by customers will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._myReviews.map(_buildReviewCard),
        ],
      ),
    );
  }

  Widget _reviewFilterChip(String label, String? status) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _reviewStatusFilter == status,
        onSelected: (_) => _loadReviews(status: status),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final Color statusColor;
    switch (review.status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }
    final name =
        review.customerName.isNotEmpty ? review.customerName : 'Customer';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd().format(review.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    review.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RatingStars(rating: review.rating.toDouble(), size: 15),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.comment!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
