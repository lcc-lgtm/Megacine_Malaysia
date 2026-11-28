import 'package:flutter/foundation.dart';

class AppConfig {
  static const String supabaseUrl = 'https://tpeapzxfksxrvgrhmwqq.supabase.co';
  static const String supabaseKey = 'sb_publishable_YMgnLnFhMAg_pwpWxQKC0w_JKPDpzBr';

  // Replace with your live Render backend URL
  static const String prodApiUrl = 'https://megacine-malaysia-api.onrender.com';

  static String get defaultApiBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    // Android emulator uses 10.0.2.2 to reach host localhost
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
