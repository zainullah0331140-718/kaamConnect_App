import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/provider_model.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _keyFavorites = 'kc_cached_favorites_v1';
  final ApiClient _api = ApiClient();

  List<ProviderSummary> _favorites = [];
  final Set<int> _favoriteIds = {};
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<ProviderSummary> get favorites => _favorites;
  Set<int> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isFavorite(int providerId) => _favoriteIds.contains(providerId);

  /// Load cached favorites immediately on app startup
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_keyFavorites);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List list = jsonDecode(cachedJson);
        _favorites = list.map((e) => ProviderSummary.fromJson(e)).toList();
        _favoriteIds.clear();
        for (var p in _favorites) {
          _favoriteIds.add(p.id);
        }
        notifyListeners();
      }
    } catch (_) {}

    // If authenticated, also fetch latest from server
    if (_api.accessToken != null) {
      await fetchFavorites();
    }
  }

  /// Explicitly sync or update single provider favorite status from API details
  void recordFavoriteStatus(int providerId, bool isFav) {
    if (isFav && !_favoriteIds.contains(providerId)) {
      _favoriteIds.add(providerId);
      notifyListeners();
    } else if (!isFav && _favoriteIds.contains(providerId)) {
      _favoriteIds.remove(providerId);
      _favorites.removeWhere((p) => p.id == providerId);
      notifyListeners();
    }
  }

  /// Fetch user's saved favorites from the backend
  Future<void> fetchFavorites() async {
    // If not authenticated, do not wipe out offline favorites
    if (_api.accessToken == null) {
      return;
    }

    if (_favorites.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final res = await _api.get('/favorites/me', authenticated: true);
      if (res is List) {
        final serverList = res.map((e) => ProviderSummary.fromJson(e)).toList();
        _favorites = serverList;
        _favoriteIds.clear();
        for (var p in _favorites) {
          _favoriteIds.add(p.id);
        }
        await _saveToPrefs();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle favorite on/off. Works seamlessly online and offline!
  Future<bool> toggleFavorite(ProviderSummary provider) async {
    final providerId = provider.id;
    final currentlyFavorite = _favoriteIds.contains(providerId);

    if (currentlyFavorite) {
      // Remove
      _favoriteIds.remove(providerId);
      _favorites.removeWhere((p) => p.id == providerId);
      notifyListeners();
      await _saveToPrefs();

      if (_api.accessToken != null) {
        try {
          await _api.delete('/favorites/$providerId', authenticated: true);
        } catch (_) {}
      }
      return false; // Removed
    } else {
      // Add
      _favoriteIds.add(providerId);
      if (!_favorites.any((p) => p.id == providerId)) {
        _favorites.insert(0, provider);
      }
      notifyListeners();
      await _saveToPrefs();

      if (_api.accessToken != null) {
        try {
          await _api.post('/favorites/$providerId', authenticated: true);
        } catch (_) {}
      }
      return true; // Added
    }
  }

  /// Clears server-specific state on logout while keeping app state clean
  Future<void> clearOnLogout() async {
    _favorites.clear();
    _favoriteIds.clear();
    _error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFavorites);
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favorites.map((e) => e.toJson()).toList();
      await prefs.setString(_keyFavorites, jsonEncode(jsonList));
    } catch (_) {}
  }
}
