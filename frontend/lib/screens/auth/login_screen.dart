import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _phone = '';
  String _dialCode = '+1';
  bool _loading = false;

  Future<void> _sendOtp() async {
    if (_phone.isEmpty) return;
    final fullPhone = '$_dialCode$_phone';

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    await auth.sendOtp(fullPhone);
    setState(() => _loading = false);

    if (!mounted) return;
    if (auth.error != null && auth.state == AuthState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppTheme.error),
      );
    } else {
      Navigator.pushNamed(context, '/otp', arguments: {'phone': fullPhone});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, Color(0xFF9C8FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 36),
              const Text(
                'Welcome to\nStok',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.onSurface, height: 1.2),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your phone number to get started',
                style: TextStyle(fontSize: 16, color: AppTheme.onSurfaceMuted),
              ),
              const SizedBox(height: 48),
              IntlPhoneField(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '000 000 0000',
                ),
                initialCountryCode: 'US',
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 16),
                dropdownTextStyle: const TextStyle(color: AppTheme.onSurface),
                onChanged: (phone) {
                  _phone = phone.number;
                  _dialCode = phone.countryCode;
                },
                onSubmitted: (_) => _sendOtp(),
              ),
              const SizedBox(height: 28),
              _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : ElevatedButton(
                      onPressed: _sendOtp,
                      child: const Text('Continue'),
                    ),
              const Spacer(),
              const Center(
                child: Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted, height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
