import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class GoogleOAuthHelper {
  static const String _desktopRedirect = 'http://127.0.0.1:54321/callback';
  static const String _mobileRedirect = 'megacine://login-callback';

  static String? _extractAccessToken(Uri uri) {
    if (uri.queryParameters['access_token'] != null) {
      return uri.queryParameters['access_token'];
    }
    if (uri.fragment.isNotEmpty) {
      final fragParams = Uri.splitQueryString(uri.fragment);
      if (fragParams['access_token'] != null) {
        return fragParams['access_token'];
      }
    }
    return null;
  }

  static Future<String> signInWithGoogle() async {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) {
      return _signInDesktop();
    }
    return _signInMobile();
  }

  static Future<String> _signInDesktop() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 54321);
    final completer = Completer<String>();

    const bridgeHtml = '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Megacine Sign-In</title>
<style>body{font-family:sans-serif;background:#0f172a;color:#f8fafc;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.box{background:#1e293b;padding:28px 36px;border-radius:12px;text-align:center;border:1px solid #334155}</style></head>
<body><div class="box"><h2 id="msg">Completing Google Sign-In...</h2><p style="color:#94a3b8">You can close this tab once finished.</p></div>
<script>
const p = new URLSearchParams(window.location.hash.substring(1));
const token = p.get('access_token') || new URLSearchParams(window.location.search).get('access_token');
const err = p.get('error_description') || new URLSearchParams(window.location.search).get('error_description');
if (token) {
  fetch('/token?access_token=' + encodeURIComponent(token)).then(() => {
    document.getElementById('msg').innerText = '✅ Signed in to Megacine Malaysia! You may close this tab.';
  });
} else {
  fetch('/token?error=' + encodeURIComponent(err || 'No access token returned'));
  document.getElementById('msg').innerText = '❌ Sign-in failed: ' + (err || 'Unknown error');
}
</script></body></html>
''';

    server.listen((HttpRequest req) async {
      if (req.uri.path == '/callback') {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(bridgeHtml);
        await req.response.close();
      } else if (req.uri.path == '/token') {
        final token = req.uri.queryParameters['access_token'];
        final err = req.uri.queryParameters['error'];
        req.response
          ..statusCode = 200
          ..write('ok');
        await req.response.close();
        if (!completer.isCompleted) {
          if (token != null && token.isNotEmpty) {
            completer.complete(token);
          } else {
            completer.completeError(Exception(err ?? 'Google sign-in cancelled'));
          }
        }
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });

    final authUri = Uri.parse(
      '${AppConfig.supabaseUrl}/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(_desktopRedirect)}',
    );
    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    try {
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw Exception('Google sign-in timed out. Please try again.'),
      );
    } finally {
      await server.close(force: true);
    }
  }

  static Future<String> _signInMobile() async {
    final appLinks = AppLinks();
    final completer = Completer<String>();
    late final StreamSubscription<Uri> sub;

    sub = appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'megacine' && uri.host == 'login-callback') {
        final token = _extractAccessToken(uri);
        if (!completer.isCompleted) {
          if (token != null && token.isNotEmpty) {
            completer.complete(token);
          } else {
            completer.completeError(Exception('Google sign-in failed to return access token.'));
          }
        }
      }
    });

    final authUri = Uri.parse(
      '${AppConfig.supabaseUrl}/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(_mobileRedirect)}',
    );
    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    try {
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw Exception('Google sign-in timed out. Please try again.'),
      );
    } finally {
      await sub.cancel();
    }
  }
}
