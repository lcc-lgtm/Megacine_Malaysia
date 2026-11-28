import 'package:flutter/material.dart';
import '../services/google_oauth_helper.dart';
import '../services/api_client.dart';
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
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_movies, size: 52, color: Colors.blueAccent),
                    const SizedBox(height: 10),
                    const Text('Megacine Malaysia', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_isSignUp ? 'Create your cinema account' : 'Welcome back',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 18),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign In'), icon: Icon(Icons.login)),
                        ButtonSegment(value: true, label: Text('Create Account'), icon: Icon(Icons.person_add)),
                      ],
                      selected: {_isSignUp},
                      onSelectionChanged: (s) => setState(() {
                        _isSignUp = s.first;
                        _errorText = null;
                        if (_isSignUp) _suggestedPwd = PasswordHelper.generateRandom12();
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_recentEmails.isNotEmpty && !_isSignUp) ...[
                      const Text('Quick Switch Account', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _recentEmails.map((em) => ActionChip(
                          avatar: const Icon(Icons.account_circle, size: 16),
                          label: Text(em, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() { _emailCtrl.text = em; }),
                        )).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
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
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() { _obscure = !_obscure; }),
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Suggested 12-char Password',
                                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  SelectableText(_suggestedPwd,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Regenerate',
                              icon: const Icon(Icons.refresh, size: 20),
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
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: SelectableText(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: Colors.grey))),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _loading ? null : _googleSignIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
