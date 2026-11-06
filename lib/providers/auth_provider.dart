import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null && _api.accessToken != null;

  Future<void> init() async {
    _api.onSessionExpired = () {
      _user = null;
      notifyListeners();
    };
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(AppConstants.keyUserData);
    if (cached != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(cached));
        notifyListeners();
      } catch (_) {}
    }

    if (_api.accessToken != null) {
      await fetchCurrentUser();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/login',
        body: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final accessToken = res['access_token'];
      final refreshToken = res['refresh_token'];

      if (accessToken != null) {
        await _api.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        await fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw ApiException('Invalid token response from server');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerCustomer({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/register/customer',
        body: {
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'phone': phone?.trim().isEmpty ?? true ? null : phone!.trim(),
        },
      );

      final accessToken = res['access_token'];
      final refreshToken = res['refresh_token'];
      if (accessToken != null) {
        await _api.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        await fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerProvider({
    required String fullName,
    required String email,
    required String password,
    required String businessName,
    required String city,
    String? area,
    String? address,
    int experienceYears = 0,
    String? description,
    String? phone,
    String? contactPhone,
    String? whatsappNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/register/provider',
        body: {
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'business_name': businessName.trim(),
          'city': city.trim(),
          'area': area?.trim().isEmpty ?? true ? null : area!.trim(),
          'address': address?.trim().isEmpty ?? true ? null : address!.trim(),
          'experience_years': experienceYears,
          'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
          'phone': phone?.trim().isEmpty ?? true ? null : phone!.trim(),
          'contact_phone': contactPhone?.trim().isEmpty ?? true ? null : contactPhone!.trim(),
          'whatsapp_number': whatsappNumber?.trim().isEmpty ?? true ? null : whatsappNumber!.trim(),
        },
      );

      final accessToken = res['access_token'];
      final refreshToken = res['refresh_token'];
      if (accessToken != null) {
        await _api.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        await fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCurrentUser() async {
    try {
      final res = await _api.get('/auth/me', authenticated: true);
      _user = UserModel.fromJson(res);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUserData, jsonEncode(_user!.toJson()));
      notifyListeners();
    } catch (_) {
      // If fetching me fails (e.g. invalid/expired token), don't crash
    }
  }

  Future<bool> deleteAccount(String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.delete(
        '/users/me',
        authenticated: true,
        body: {'password': password},
      );
      await _api.clearTokens();
      _user = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', authenticated: true);
    } catch (_) {}
    await _api.clearTokens();
    _user = null;
    notifyListeners();
  }
}
