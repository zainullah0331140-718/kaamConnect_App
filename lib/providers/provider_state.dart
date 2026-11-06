import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/advertisement_model.dart';
import '../models/category_model.dart';
import '../models/provider_model.dart';
import '../models/review_model.dart';

class ProviderState extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  // Home Screen Data
  List<CategoryModel> _categories = [];
  List<ProviderSummary> _featuredProviders = [];
  List<ProviderSummary> _recentProviders = [];
  List<AdvertisementModel> _advertisements = [];
  bool _isHomeLoading = false;
  String? _homeError;

  // Search & Explore Data
  List<ProviderSummary> _searchResults = [];
  int _searchTotal = 0;
  int _searchPage = 1;
  bool _isSearching = false;
  String? _searchError;

  // Search Filters
  String _searchQuery = '';
  String? _selectedCategorySlug;
  String? _selectedCity;
  double _minRating = 0.0;
  bool? _verifiedOnly;
  String _sort = 'rating'; // 'rating', 'newest', 'name'

  // Provider Detail
  ProviderDetail? _selectedProvider;
  List<ReviewModel> _providerReviews = [];
  bool _isDetailLoading = false;
  String? _detailError;

  // Getters
  List<CategoryModel> get categories => _categories;
  List<ProviderSummary> get featuredProviders => _featuredProviders;
  List<ProviderSummary> get recentProviders => _recentProviders;
  List<AdvertisementModel> get advertisements => _advertisements;
  bool get isHomeLoading => _isHomeLoading;
  String? get homeError => _homeError;

  List<ProviderSummary> get searchResults => _searchResults;
  int get searchTotal => _searchTotal;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  String get searchQuery => _searchQuery;
  String? get selectedCategorySlug => _selectedCategorySlug;
  String? get selectedCity => _selectedCity;
  double get minRating => _minRating;
  bool? get verifiedOnly => _verifiedOnly;
  String get sort => _sort;

  ProviderDetail? get selectedProvider => _selectedProvider;
  List<ReviewModel> get providerReviews => _providerReviews;
  bool get isDetailLoading => _isDetailLoading;
  String? get detailError => _detailError;

  // Setters for filters
  void setSearchQuery(String q) {
    _searchQuery = q;
  }

  void selectCategory(String? slug) {
    _selectedCategorySlug = (_selectedCategorySlug == slug) ? null : slug;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void selectCity(String? city) {
    if (city == 'All Cities') {
      _selectedCity = null;
    } else {
      _selectedCity = city;
    }
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void setMinRating(double rating) {
    _minRating = rating;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void setVerifiedOnly(bool? verified) {
    _verifiedOnly = verified;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void setSort(String sortType) {
    _sort = sortType;
    notifyListeners();
    searchProviders(resetPage: true);
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategorySlug = null;
    _selectedCity = null;
    _minRating = 0.0;
    _verifiedOnly = null;
    _sort = 'rating';
    notifyListeners();
    searchProviders(resetPage: true);
  }

  // Fetch Home Screen Data
  Future<void> fetchHomeData() async {
    _isHomeLoading = true;
    _homeError = null;
    notifyListeners();

    try {
      // 1. Categories
      final catData = await _api.get('/categories');
      if (catData is List) {
        _categories = catData.map((e) => CategoryModel.fromJson(e)).toList();
      }

      // 2. Featured Providers
      final featData = await _api.get('/providers/featured', queryParams: {'limit': '6'});
      if (featData is List) {
        _featuredProviders = featData.map((e) => ProviderSummary.fromJson(e)).toList();
      }

      // 3. Recent Providers
      final recData = await _api.get('/providers/recent', queryParams: {'limit': '8'});
      if (recData is List) {
        _recentProviders = recData.map((e) => ProviderSummary.fromJson(e)).toList();
      }

      // 4. Advertisements
      try {
        final adData = await _api.get('/advertisements/public');
        if (adData is List) {
          _advertisements = adData.map((e) => AdvertisementModel.fromJson(e)).toList();
        }
      } catch (_) {
        // Ads endpoint might be empty
      }

      _isHomeLoading = false;
      notifyListeners();
    } catch (e) {
      _homeError = e.toString();
      _isHomeLoading = false;
      notifyListeners();
    }
  }

  // Search & Filter Providers
  Future<void> searchProviders({bool resetPage = false}) async {
    if (resetPage) {
      _searchPage = 1;
      _searchResults = [];
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'page': _searchPage.toString(),
        'page_size': '20',
        'sort': _sort,
      };

      if (_searchQuery.trim().isNotEmpty) {
        queryParams['q'] = _searchQuery.trim();
      }
      if (_selectedCategorySlug != null && _selectedCategorySlug!.isNotEmpty) {
        queryParams['category'] = _selectedCategorySlug;
      }
      if (_selectedCity != null && _selectedCity!.isNotEmpty) {
        queryParams['city'] = _selectedCity;
      }
      if (_minRating > 0) {
        queryParams['min_rating'] = _minRating.toString();
      }
      if (_verifiedOnly == true) {
        queryParams['verified'] = 'true';
      }

      final res = await _api.get('/providers', queryParams: queryParams);
      if (res is Map && res['items'] is List) {
        final List list = res['items'];
        final parsed = list.map((e) => ProviderSummary.fromJson(e)).toList();
        if (resetPage) {
          _searchResults = parsed;
        } else {
          _searchResults.addAll(parsed);
        }
        _searchTotal = res['total'] ?? _searchResults.length;
      }

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _searchError = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  // Load single Provider Detail
  Future<void> fetchProviderDetail(int providerId) async {
    _isDetailLoading = true;
    _detailError = null;
    _selectedProvider = null;
    _providerReviews = [];
    notifyListeners();

    try {
      final detailRes = await _api.get('/providers/$providerId', authenticated: true);
      _selectedProvider = ProviderDetail.fromJson(detailRes);

      // Load Reviews
      try {
        final reviewRes = await _api.get('/reviews', queryParams: {'provider_id': providerId.toString()});
        if (reviewRes is Map && reviewRes['items'] is List) {
          _providerReviews = (reviewRes['items'] as List)
              .map((r) => ReviewModel.fromJson(r))
              .toList();
        } else if (reviewRes is List) {
          _providerReviews = reviewRes.map((r) => ReviewModel.fromJson(r)).toList();
        }
      } catch (_) {}

      _isDetailLoading = false;
      notifyListeners();
    } catch (e) {
      _detailError = e.toString();
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  // Post Review
  Future<bool> submitReview({
    required int providerId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _api.post(
        '/reviews',
        authenticated: true,
        body: {
          'provider_id': providerId,
          'rating': rating,
          'comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
        },
      );
      // Refresh detail
      await fetchProviderDetail(providerId);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Submit Complaint
  Future<bool> submitComplaint({
    required int providerId,
    required String subject,
    required String description,
  }) async {
    try {
      await _api.post(
        '/complaints',
        authenticated: true,
        body: {
          'provider_id': providerId,
          'subject': subject.trim(),
          'description': description.trim(),
        },
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
