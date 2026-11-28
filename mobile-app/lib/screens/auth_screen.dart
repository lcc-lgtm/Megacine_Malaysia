import 'package:flutter/material.dart';
import '../services/google_oauth_helper.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/password_helper.dart';
import 'home_screen.dart';
import 'username_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  final String? prefillEmail;
  const AuthScreen({super.key, this.prefillEmail});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;
  bool _loading = false;
  String? _errorText;
  String _suggestedPwd = PasswordHelper.generateRandom12();
  List<String> _recentEmails = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) _emailCtrl.text = widget.prefillEmail!;
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await ApiClient.instance.getRecentAccounts();
    if (mounted) setState(() { _recentEmails = list; });
  }

  void _routeAfterAuth(String email, String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => UsernameSetupScreen(email: email)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      _showErr('Please enter a valid email address.');
      return;
    }
    if (_isSignUp && !PasswordHelper.isValid(pwd)) {
      _showErr('New password must be 8–12 chars using only a-z, A-Z, 0-9, #, \$');
      return;
    }
    if (!_isSignUp && pwd.isEmpty) {
      _showErr('Please enter your password.');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final profile = _isSignUp
          ? await ApiClient.instance.signUp(email, pwd)
          : await ApiClient.instance.signIn(email, pwd);
      if (!mounted) return;
      _routeAfterAuth(profile.email, profile.fullName);
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final token = await GoogleOAuthHelper.signInWithGoogle();
      final profile = await ApiClient.instance.signInWithToken(token);
      if (!mounted) return;
      _routeAfterAuth(profile.email, profile.fullName);
    } catch (e) {
      if (!mounted) return;
      _showErr(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _showErr(String msg) {
    setState(() { _errorText = msg; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.crimson),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.crimsonTint,
                            borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(Icons.local_movies_outlined, size: 28, color: AppTheme.crimson),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Megacine Malaysia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSignUp ? 'Create your cinema account' : 'Sign in to your screening pass',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.inkSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sign In'), icon: Icon(Icons.login, size: 18)),
                          ButtonSegment(value: true, label: Text('Create Account'), icon: Icon(Icons.person_add, size: 18)),
                        ],
                        selected: {_isSignUp},
                        onSelectionChanged: (s) => setState(() {
                          _isSignUp = s.first;
                          _errorText = null;
                          if (_isSignUp) _suggestedPwd = PasswordHelper.generateRandom12();
                        }),
                      ),
                      const SizedBox(height: 18),
                      if (_recentEmails.isNotEmpty && !_isSignUp) ...[
                        const Text(
                          'QUICK SWITCH ACCOUNT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: AppTheme.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _recentEmails
                              .map(
                                (em) => ActionChip(
                                  avatar: const Icon(Icons.account_circle_outlined, size: 16, color: AppTheme.inkSecondary),
                                  label: Text(
                                    em,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.inkPrimary),
                                  ),
                                  onPressed: () => setState(() { _emailCtrl.text = em; }),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pwdCtrl,
                        obscureText: _obscure,
                        maxLength: _isSignUp ? 12 : null,
                        decoration: InputDecoration(
                          labelText: _isSignUp ? 'Password (8–12 chars: a-z, A-Z, 0-9, #, \$)' : 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() { _obscure = !_obscure; }),
                          ),
                        ),
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.canvasMuted,
                            borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Suggested 12-char Password',
                                      style: TextStyle(fontSize: 11, color: AppTheme.inkSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    SelectableText(
                                      _suggestedPwd,
                                      style: AppTheme.monoTabular(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.inkPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Regenerate',
                                icon: const Icon(Icons.refresh, size: 20, color: AppTheme.inkSecondary),
                                onPressed: () => setState(() { _suggestedPwd = PasswordHelper.generateRandom12(); }),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _pwdCtrl.text = _suggestedPwd;
                                  _obscure = false;
                                }),
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.crimsonTint,
                            borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                            border: Border.all(color: AppTheme.crimson),
                          ),
                          child: SelectableText(
                            _errorText!,
                            style: const TextStyle(color: AppTheme.crimsonPressed, fontSize: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR', style: TextStyle(color: AppTheme.inkMuted, fontSize: 12)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.g_mobiledata, size: 26),
                        label: const Text('Continue with Google'),
                        onPressed: _loading ? null : _googleSignIn,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
