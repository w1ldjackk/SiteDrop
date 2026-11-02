// lib/presentation/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/presentation/theme/auth_theme.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import '../../widgets/common/app_back_button.dart';
import 'package:sitedrop_core/presentation/widgets/forms/otp_pin_fields.dart';

enum _ResetMethod { email, phone }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  _ResetMethod _method = _ResetMethod.email;
  bool _isLoading = false;

  /// After send: show code + password for both email and phone.
  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
            _startTimer();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _switchMethod(_ResetMethod method) {
    if (_method == method) return;
    setState(() {
      _method = method;
      _codeSent = false;
      _isLoading = false;
      _canResend = false;
      _resendTimer = 60;
      for (final c in _otpControllers) {
        c.clear();
      }
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = _method == _ResetMethod.email
        ? await ref
              .read(authProvider.notifier)
              .forgotPassword(email: _emailController.text.trim())
        : await ref
              .read(authProvider.notifier)
              .forgotPassword(
                phone: Helpers.formatPhoneNumber(_phoneController.text.trim()),
              );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.when(
      data: (response) {
        setState(() {
          _codeSent = true;
          _resendTimer = 60;
          _canResend = false;
        });
        final message =
            response['message'] as String? ??
            (_method == _ResetMethod.email
                ? 'Reset link and code sent to your email'
                : 'Reset link and code sent to your phone');
        Helpers.showSuccessToast(message);
        _startTimer();
      },
      error: (error, stack) {
        Helpers.showErrorToast(error.toString());
      },
      loading: () {},
    );
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendTimer = 60;
    });

    final result = _method == _ResetMethod.email
        ? await ref
              .read(authProvider.notifier)
              .forgotPassword(email: _emailController.text.trim())
        : await ref
              .read(authProvider.notifier)
              .forgotPassword(
                phone: Helpers.formatPhoneNumber(_phoneController.text.trim()),
              );

    if (!mounted) return;

    result.when(
      data: (_) {
        Helpers.showSuccessToast('Code and link resent successfully');
        _startTimer();
      },
      error: (error, stack) {
        Helpers.showErrorToast(error.toString());
        setState(() {
          _canResend = true;
          _resendTimer = 0;
        });
      },
      loading: () {},
    );
  }

  Future<void> _handleResetPassword() async {
    if (_otpCode.length < 6) {
      Helpers.showErrorToast('Please enter the complete 6-digit code');
      return;
    }

    final password = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      Helpers.showErrorToast('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      Helpers.showErrorToast('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    final result = _method == _ResetMethod.email
        ? await ref
              .read(authProvider.notifier)
              .resetPassword(
                email: _emailController.text.trim(),
                code: _otpCode,
                password: password,
                passwordConfirmation: confirmPassword,
              )
        : await ref
              .read(authProvider.notifier)
              .resetPassword(
                phone: Helpers.formatPhoneNumber(_phoneController.text.trim()),
                code: _otpCode,
                password: password,
                passwordConfirmation: confirmPassword,
              );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.when(
      data: (_) {
        Helpers.showSuccessToast('Password reset successfully!');
        context.go(RouteNames.login);
      },
      error: (error, stack) {
        Helpers.showErrorToast(error.toString());
      },
      loading: () {},
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return AuthTheme.field(
      context,
      hint: hint,
      icon: icon,
      suffixIcon: suffixIcon,
    );
  }

  String get _subtitle {
    if (!_codeSent) {
      return _method == _ResetMethod.email
          ? 'We\'ll email a reset link and a 6-digit code'
          : 'We\'ll text a reset link and a 6-digit code';
    }
    return _method == _ResetMethod.email
        ? 'Enter the code from your email, or open the link instead'
        : 'Enter the code from your SMS, or open the link instead';
  }

  Widget _buildMethodToggle() {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _MethodChip(
              label: 'Email',
              icon: Icons.email_outlined,
              selected: _method == _ResetMethod.email,
              onTap: () => _switchMethod(_ResetMethod.email),
            ),
          ),
          Expanded(
            child: _MethodChip(
              label: 'Phone',
              icon: Icons.phone_outlined,
              selected: _method == _ResetMethod.phone,
              onTap: () => _switchMethod(_ResetMethod.phone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _canResend ? 'Didn\'t get it?' : 'Resend in ',
          style: TextStyle(color: context.palette.textMuted, fontSize: 14),
        ),
        if (!_canResend) ...[
          Text(
            '$_resendTimer',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
          Text(
            's',
            style: TextStyle(fontSize: 14, color: context.palette.textMuted),
          ),
        ],
        if (_canResend)
          TextButton(
            onPressed: _handleResend,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Resend code & link',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkOrCodeHint() {
    final p = context.palette;
    final isEmail = _method == _ResetMethod.email;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEmail
                  ? 'We sent a link and a 6-digit code to ${_emailController.text.trim()}. Open the link in a browser, or enter the code below.'
                  : 'We sent a link and a 6-digit code by SMS. Open the link in a browser, or enter the code below.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Password',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
          decoration: _buildInputDecoration(
            hint: 'Enter new password (min 6 characters)',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: context.palette.iconMuted,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: Validators.password,
        ),
        const SizedBox(height: 16),
        Text(
          'Confirm Password',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
          decoration: _buildInputDecoration(
            hint: 'Re-enter your password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: context.palette.iconMuted,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
          ),
          validator: (value) => Validators.passwordConfirmation(
            value,
            _newPasswordController.text,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.scaffoldBg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButton(
                  fallbackRoute: RouteNames.login,
                  margin: EdgeInsets.zero,
                  onPressed: () {
                    if (_codeSent) {
                      setState(() {
                        _codeSent = false;
                        for (final c in _otpControllers) {
                          c.clear();
                        }
                      });
                      return;
                    }
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.login);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Reset Password',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.palette.iconMuted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),

                if (!_codeSent) ...[
                  _buildMethodToggle(),
                  const SizedBox(height: 24),
                ],

                // Contact field
                Text(
                  _method == _ResetMethod.email
                      ? 'Email Address'
                      : 'Phone Number',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_method == _ResetMethod.email)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_codeSent,
                    autofillHints: const [AutofillHints.email],
                    style: TextStyle(
                      fontSize: 16,
                      color: context.palette.textPrimary,
                    ),
                    decoration: _buildInputDecoration(
                      hint: 'Enter your registered email',
                      icon: Icons.email_outlined,
                    ),
                    validator: Validators.email,
                  )
                else
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !_codeSent,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.palette.textPrimary,
                    ),
                    decoration: _buildInputDecoration(
                      hint: 'Enter your registered phone number',
                      icon: Icons.phone_outlined,
                    ),
                    validator: Validators.phone,
                  ),

                if (_codeSent) ...[
                  const SizedBox(height: 16),
                  _buildLinkOrCodeHint(),
                  const SizedBox(height: 24),
                  Text(
                    'Enter 6-digit code',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OtpPinFields(
                    controllers: _otpControllers,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 12),
                  _buildResendRow(),
                  const SizedBox(height: 24),
                  _buildPasswordFields(),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: _handleResetPassword,
                    isLoading: _isLoading,
                    text: 'Reset Password',
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: _handleSend,
                    isLoading: _isLoading,
                    text: _method == _ResetMethod.email
                        ? 'Send Link & Code'
                        : 'Send Link & Code',
                  ),
                ],

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(RouteNames.login),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : context.palette.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: selected
                      ? Colors.white
                      : context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
