import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'KaamConnect';
  static const String appTagline = 'Connecting You to Trusted Local Services';

  // Default server URLs:
  // - On Windows Desktop / PC / macOS / Linux / Web: localhost:8000
  // - On Android Emulator: 10.0.2.2:8000
  // - On physical iPhone / Android device: User's LAN IP (can be customized via in-app Settings)
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:8000';
    }
  }

  static const String apiV1Prefix = '/api/v1';

  // Storage Keys
  static const String keyBaseUrl = 'kc_base_url';
  static const String keyAccessToken = 'kc_access_token';
  static const String keyRefreshToken = 'kc_refresh_token';
  static const String keyUserData = 'kc_user_data';
  static const String keyThemeMode = 'kc_theme_mode';

  // Major Pakistani Cities
  static const List<String> pakistaniCities = [
    'All Cities',
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
    'Gujranwala',
    'Sialkot',
    'Hyderabad',
    'Abbottabad',
    'Bahawalpur',
    'Sargodha',
    'Sukkur',
  ];

  // Colors
  static const Color primaryColor = Color(0xFF0D9488); // Emerald Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color secondaryColor = Color(0xFFF59E0B); // Warm Amber
  static const Color accentGold = Color(0xFFD97706);
  static const Color verifiedGreen = Color(0xFF10B981);
  static const Color pendingYellow = Color(0xFFFBBF24);
  static const Color rejectedRed = Color(0xFFEF4444);

  // Surface Colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
}
