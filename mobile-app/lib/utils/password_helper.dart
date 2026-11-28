import 'dart:math';

class PasswordHelper {
  static const String allowedChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#\$';
  static final RegExp validPattern = RegExp(r'^[a-zA-Z0-9#$]{8,12}$');

  static bool isValid(String password) => validPattern.hasMatch(password);

  static String generateRandom12() {
    final rng = Random.secure();
    const lowers = 'abcdefghijklmnopqrstuvwxyz';
    const uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    const symbols = '#\$';
    final chars = <String>[
      lowers[rng.nextInt(lowers.length)],
      uppers[rng.nextInt(uppers.length)],
      digits[rng.nextInt(digits.length)],
      symbols[rng.nextInt(symbols.length)],
      for (int i = 0; i < 8; i++) allowedChars[rng.nextInt(allowedChars.length)],
    ];
    chars.shuffle(rng);
    return chars.join();
  }

  static String suggestUsername(String email) {
    final lower = email.trim();
    if (lower.toLowerCase().endsWith('@gmail.com')) {
      return lower.substring(0, lower.length - '@gmail.com'.length);
    }
    final atIdx = lower.indexOf('@');
    return atIdx > 0 ? lower.substring(0, atIdx) : lower;
  }

  static String? extractYoutubeId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final match = RegExp(r'(?:v=|/embed/|youtu\.be/|/shorts/)([a-zA-Z0-9_-]{11})').firstMatch(url.trim());
    return match?.group(1);
  }
}
