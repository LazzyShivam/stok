import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Single controller — the real input field is hidden
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _phone = '';
  bool _loading = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _phone.isEmpty) {
      _phone = args['phone'] as String? ?? '';
    }
    if (_timer == null) _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendTimer <= 0) {
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _otp => _controller.text.trim();

  void _onTextChanged(String value) {
    // Only keep digits, max 6
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6) {
      _controller.value = TextEditingValue(
        text: digits.substring(0, 6),
        selection: TextSelection.collapsed(offset: 6),
      );
      return;
    }
    if (digits != value) {
      _controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
      return;
    }
    setState(() {});
    if (digits.length == 6) {
      // Small delay so the last box fills visually before submitting
      Future.delayed(const Duration(milliseconds: 100), _verifyOtp);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6 || _loading) return;
    setState(() => _loading = true);
    _focusNode.unfocus();

    final auth = context.read<AuthProvider>();
    final isNewUser = await auth.verifyOtp(_phone, otp);
    if (!mounted) return;
    setState(() => _loading = false);

    if (auth.isAuthenticated) {
      final token = await context.read<AuthService>().getToken();
      if (token != null) {
        context.read<SocketService>().connect(token);
      }
      if (isNewUser) {
        Navigator.pushNamedAndRemoveUntil(context, '/profile-setup', (route) => false);
      } else {
        await context.read<ChatProvider>().loadConversations();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Invalid OTP'), backgroundColor: AppTheme.error),
      );
      _controller.clear();
      setState(() {});
      Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
    }
  }

  Future<void> _resendOtp() async {
    if (_resendTimer > 0) return;
    final auth = context.read<AuthProvider>();
    await auth.sendOtp(_phone);
    _startResendTimer();
    _controller.clear();
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent successfully'), backgroundColor: AppTheme.success),
    );
  }

  void _fillDev() {
    _controller.value = const TextEditingValue(
      text: '123456',
      selection: TextSelection.collapsed(offset: 6),
    );
    setState(() {});
    Future.delayed(const Duration(milliseconds: 150), _verifyOtp);
  }

  @override
  Widget build(BuildContext context) {
    final otp = _otp;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: AppTheme.primary, size: 28),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Verify Phone',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code sent to\n$_phone',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.onSurfaceMuted,
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 44),

                // Hidden real TextField
                SizedBox(
                  width: 0,
                  height: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onTextChanged,
                    autofocus: true,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.transparent, fontSize: 1),
                    cursorColor: Colors.transparent,
                    cursorWidth: 0,
                  ),
                ),

                // OTP boxes (visual only — tapping opens keyboard)
                GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final char = i < otp.length ? otp[i] : '';
                      final isCurrent = i == otp.length && !_loading;
                      final isFilled = char.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: 48,
                          height: 58,
                          decoration: BoxDecoration(
                            color: isFilled
                                ? AppTheme.primary.withOpacity(0.18)
                                : const Color(0xFF1C1C2E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? AppTheme.primary
                                  : isFilled
                                      ? AppTheme.primary.withOpacity(0.5)
                                      : const Color(0xFF2E2E50),
                              width: isCurrent ? 2.5 : 1.5,
                            ),
                            boxShadow: isCurrent
                                ? [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 12)]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: isFilled
                              ? Text(
                                  char,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                )
                              : isCurrent
                                  ? _BlinkingCursor()
                                  : const SizedBox.shrink(),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 40),

                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: otp.length == 6 ? _verifyOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor: AppTheme.primary.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: _resendTimer == 0 ? _resendOtp : null,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 14),
                          children: [
                            const TextSpan(
                              text: "Didn't receive code? ",
                              style: TextStyle(color: AppTheme.onSurfaceMuted),
                            ),
                            TextSpan(
                              text: _resendTimer > 0
                                  ? 'Resend in ${_resendTimer}s'
                                  : 'Resend',
                              style: TextStyle(
                                color: _resendTimer > 0 ? AppTheme.onSurfaceMuted : AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Dev helper
                Center(
                  child: TextButton(
                    onPressed: _fillDev,
                    child: const Text(
                      'DEV: Fill 123456',
                      style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Blinking cursor indicator for current OTP box
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 2,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
