import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String _baseUrl = AppConstants.defaultBaseUrl;
  String? _accessToken;
  String? _refreshToken;

  /// Called when an expired session could not be refreshed and tokens were cleared.
  void Function()? onSessionExpired;

  String get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(AppConstants.keyBaseUrl) ?? AppConstants.defaultBaseUrl;
    _accessToken = prefs.getString(AppConstants.keyAccessToken);
    _refreshToken = prefs.getString(AppConstants.keyRefreshToken);
  }

  Future<void> setBaseUrl(String url) async {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyBaseUrl, _baseUrl);
  }

  Future<void> setTokens({required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAccessToken, accessToken);
    if (refreshToken != null) {
      await prefs.setString(AppConstants.keyRefreshToken, refreshToken);
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAccessToken);
    await prefs.remove(AppConstants.keyRefreshToken);
    await prefs.remove(AppConstants.keyUserData);
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final fullPath = path.startsWith('/api/') ? path : '${AppConstants.apiV1Prefix}$path';
    final baseUri = Uri.parse(_baseUrl);

    Map<String, String>? cleanParams;
    if (queryParams != null && queryParams.isNotEmpty) {
      cleanParams = {};
      queryParams.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          cleanParams![key] = value.toString();
        }
      });
    }

    if (baseUri.isScheme('HTTPS')) {
      return Uri.https(baseUri.authority, '${baseUri.path}$fullPath', cleanParams);
    } else {
      return Uri.http(baseUri.authority, '${baseUri.path}$fullPath', cleanParams);
    }
  }

  Map<String, String> _buildHeaders({bool authenticated = false, bool isJson = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (authenticated && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMessage = 'Request failed (${response.statusCode})';
    if (body is Map) {
      if (body['detail'] is String) {
        errorMessage = body['detail'];
      } else if (body['detail'] is List) {
        final list = body['detail'] as List;
        if (list.isNotEmpty && list.first is Map && list.first['msg'] != null) {
          errorMessage = list.first['msg'].toString();
        }
      } else if (body['message'] is String) {
        errorMessage = body['message'];
      }
      final fieldErrors = body['errors'];
      if (fieldErrors is List && fieldErrors.isNotEmpty) {
        final messages = fieldErrors
            .whereType<Map>()
            .map((e) => e['message']?.toString())
            .whereType<String>()
            .where((m) => m.isNotEmpty)
            .toSet()
            .take(3)
            .toList();
        if (messages.isNotEmpty) {
          errorMessage = errorMessage == 'Validation failed'
              ? messages.join('\n')
              : '$errorMessage: ${messages.join(', ')}';
        }
      }
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      details: body,
    );
  }

  Future<bool> _refreshAccessToken() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) return false;
    try {
      final uri = _buildUri('/auth/refresh');
      final response = await http.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': token}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final access = body is Map ? body['access_token'] : null;
        final refresh = body is Map ? body['refresh_token'] : null;
        if (access is String && access.isNotEmpty) {
          await setTokens(
            accessToken: access,
            refreshToken:
                refresh is String && refresh.isNotEmpty ? refresh : token,
          );
          return true;
        }
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _handleSessionExpired();
      }
    } catch (_) {
      // Network error: keep the current tokens so the user can retry.
    }
    return false;
  }

  Future<void> _handleSessionExpired() async {
    await clearTokens();
    onSessionExpired?.call();
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool authenticated,
  }) async {
    var response = await request();
    if (authenticated && response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await request();
      }
    }
    return response;
  }

  Future<dynamic> _guard(Future<dynamic> Function() action) async {
    try {
      return await action();
    } on http.ClientException {
      throw ApiException(
          'Cannot reach KaamConnect server. Check connection & server URL.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool authenticated = false,
  }) {
    return _guard(() async {
      final uri = _buildUri(path, queryParams);
      final response = await _send(
        () => http.get(
          uri,
          headers: _buildHeaders(authenticated: authenticated),
        ),
        authenticated: authenticated,
      );
      return _handleResponse(response);
    });
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    bool authenticated = false,
  }) {
    return _guard(() async {
      final uri = _buildUri(path);
      final response = await _send(
        () => http.post(
          uri,
          headers: _buildHeaders(authenticated: authenticated),
          body: body != null ? jsonEncode(body) : null,
        ),
        authenticated: authenticated,
      );
      return _handleResponse(response);
    });
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    bool authenticated = false,
  }) {
    return _guard(() async {
      final uri = _buildUri(path);
      final response = await _send(
        () => http.patch(
          uri,
          headers: _buildHeaders(authenticated: authenticated),
          body: body != null ? jsonEncode(body) : null,
        ),
        authenticated: authenticated,
      );
      return _handleResponse(response);
    });
  }

  Future<dynamic> delete(
    String path, {
    dynamic body,
    bool authenticated = true,
  }) {
    return _guard(() async {
      final uri = _buildUri(path);
      final response = await _send(
        () => http.delete(
          uri,
          headers: _buildHeaders(authenticated: authenticated),
          body: body != null ? jsonEncode(body) : null,
        ),
        authenticated: authenticated,
      );
      return _handleResponse(response);
    });
  }

  // Upload single file with optional form fields (e.g. profile picture or advertisement)
  Future<dynamic> uploadFile(
    String path, {
    required String fileField,
    required XFile file,
    Map<String, String>? fields,
    String method = 'POST',
  }) {
    return _guard(() async {
      final uri = _buildUri(path);
      final authenticated = _accessToken != null;

      Future<http.Response> send() async {
        final request = http.MultipartRequest(method, uri);
        if (_accessToken != null) {
          request.headers['Authorization'] = 'Bearer $_accessToken';
        }
        request.headers['Accept'] = 'application/json';
        if (fields != null) {
          request.fields.addAll(fields);
        }
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            bytes,
            filename: file.name.isNotEmpty ? file.name : 'upload.jpg',
          ),
        );
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      }

      final response = await _send(send, authenticated: authenticated);
      return _handleResponse(response);
    });
  }

  // Upload multiple files (e.g. up to 5 work portfolio photos)
  Future<dynamic> uploadMultipleFiles(
    String path, {
    required String filesField,
    required List<XFile> files,
    Map<String, String>? fields,
  }) {
    return _guard(() async {
      final uri = _buildUri(path);
      final authenticated = _accessToken != null;

      Future<http.Response> send() async {
        final request = http.MultipartRequest('POST', uri);
        if (_accessToken != null) {
          request.headers['Authorization'] = 'Bearer $_accessToken';
        }
        request.headers['Accept'] = 'application/json';
        if (fields != null) {
          request.fields.addAll(fields);
        }
        for (var file in files) {
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              filesField,
              bytes,
              filename: file.name.isNotEmpty ? file.name : 'work.jpg',
            ),
          );
        }
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      }

      final response = await _send(send, authenticated: authenticated);
      return _handleResponse(response);
    });
  }

  String getMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    var clean = path.replaceAll('\\', '/');
    if (!clean.startsWith('/')) {
      clean = '/$clean';
    }
    return '$_baseUrl$clean';
  }
}
