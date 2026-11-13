import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../data/auth_service.dart';

/// Forgot password, in two steps on one screen:
/// 1. the teacher's email → Supabase emails a 6-digit code;
/// 2. the code and a new password → saved, and the teacher is signed in.
/// The app shell hears the sign-in and swaps to the course list by itself.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email; // whatever was typed on the sign-in screen

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email you signed up with.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthService.sendResetCode(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      _codeSent = error == null;
    });
  }

  Future<void> _reset() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'The new password needs at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthService.resetPassword(_email.text.trim(), code, _password.text);
    if (!mounted) return;
    if (error == null) {
      // Signed in now: back to the bottom of the stack, where the course list has appeared.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text('New', style: AppText.heroTitle),
            Text('password.', style: AppText.heroTitle.copyWith(color: AppColors.greenText)),
            const SizedBox(height: 12),
            Text(
              _codeSent
                  ? 'We emailed a 6-digit code to ${_email.text.trim()}. It can take a minute; check spam too.'
                  : "Enter your email and we'll send you a code to set a new password.",
              style: AppText.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: AppText.input,
              decoration: const InputDecoration(labelText: 'Email'),
              onSubmitted: (_) => _codeSent ? null : _sendCode(),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: AppText.mono.copyWith(fontSize: 22, letterSpacing: 6),
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _hidden,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _reset(),
                style: AppText.input,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
            ],
            const SizedBox(height: 24),
            if (!_codeSent)
              FilledButton(onPressed: _busy ? null : _sendCode, child: Text(_busy ? 'Sending…' : 'Send code'))
            else ...[
              FilledButton(onPressed: _busy ? null : _reset, child: Text(_busy ? 'Saving…' : 'Save new password')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('Send the code again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
