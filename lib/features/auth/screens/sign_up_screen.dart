import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../data/auth_service.dart';
import 'sign_in_screen.dart';

/// Creates a teacher account. Same look as Sign in (Night screen 24).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _checkEmail = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty || _password.text.length < 6) {
      setState(() => _error = 'Enter your name, email and a password of at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loggedIn = await AuthService.signUp(name, email, _password.text);
      if (!mounted) return;
      if (loggedIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _busy = false;
          _checkEmail = true;
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Can't reach the server. Check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: _checkEmail ? _confirmation() : _form(),
        ),
      ),
    );
  }

  List<Widget> _confirmation() => [
        Text('Check your', style: AppText.heroTitle),
        Text('email.', style: AppText.heroTitle.copyWith(color: AppColors.greenText)),
        const SizedBox(height: 12),
        Text('Open the link we sent to ${_email.text.trim()}, then sign in.', style: AppText.body.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignInScreen())),
          child: const Text('Go to sign in'),
        ),
      ];

  List<Widget> _form() => [
        Text('Create your', style: AppText.heroTitle),
        Text('account.', style: AppText.heroTitle.copyWith(color: AppColors.greenText)),
        const SizedBox(height: 28),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          style: AppText.input,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          style: AppText.input,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
          style: AppText.input,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating…' : 'Create account')),
      ];
}
