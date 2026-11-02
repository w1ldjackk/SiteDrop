// lib/presentation/screens/auth/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/presentation/theme/auth_theme.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_back_button.dart';
import 'package:sitedrop_core/presentation/widgets/forms/otp_pin_fields.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _otpError = false;
  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
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

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  void _clearOtp({bool focusFirst = true}) {
    for (final c in _otpControllers) {
      c.clear();
    }
    if (focusFirst && mounted) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  Future<void> _handleVerifyOtp([String? completedCode]) async {
    if (_isLoading) return;
    final code = (completedCode ?? _otpCode).trim();
    if (code.length < 6) {
      Helpers.showErrorToast('Please enter the complete verification code');
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await ref
          .read(authProvider.notifier)
          .verifyOtp(phone: widget.phone, code: code);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (mounted) {
        if (result.hasError) {
          Helpers.showErrorToast(result.error.toString());
          setState(() => _otpError = true);
          return;
        }

        final authState = result.asData?.value;
        if (authState is AuthAuthenticated ||
            ref.read(authProvider).asData?.value is AuthAuthenticated) {
          Helpers.showSuccessToast('Phone verified successfully!');
          context.go(RouteNames.home);
          return;
        }

        Helpers.showErrorToast('Verification failed. Please try again.');
        setState(() => _otpError = true);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(e.toString());
        setState(() {
          _isLoading = false;
          _otpError = true;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendTimer = 60;
      _isLoading = true;
      _otpError = false;
    });
    _clearOtp();

    try {
      final result = await ref
          .read(authProvider.notifier)
          .sendOtp(widget.phone);

      if (mounted) {
        result.when(
          data: (_) {
            Helpers.showSuccessToast('Verification code resent successfully');
            _startTimer();
            setState(() {
              _isLoading = false;
            });
          },
          error: (error, stack) {
            Helpers.showErrorToast(error.toString());
            if (mounted) {
              setState(() {
                _canResend = true;
                _resendTimer = 0;
                _isLoading = false;
              });
            }
          },
          loading: () {},
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(e.toString());
        setState(() {
          _canResend = true;
          _resendTimer = 0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.scaffoldBg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(
                  fallbackRoute: RouteNames.login,
                  margin: EdgeInsets.zero,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.login);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.palette.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.sms_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Phone',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${Helpers.formatPhoneDisplay(widget.phone)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.palette.iconMuted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              // OTP Input Fields — auto-verifies once all 6 digits are in.
              OtpPinFields(
                controllers: _otpControllers,
                focusNodes: _otpFocusNodes,
                enabled: !_isLoading,
                hasError: _otpError,
                onChanged: (_) {
                  if (_otpError && mounted) {
                    setState(() => _otpError = false);
                  }
                },
                onCompleted: _handleVerifyOtp,
              ),
              const SizedBox(height: 12),

              // Auto-verify hint / verifying indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading
                    ? Row(
                        key: const ValueKey('verifying'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Verifying code…',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.palette.textMuted,
                                ),
                          ),
                        ],
                      )
                    : Text(
                        'Code is verified automatically',
                        key: const ValueKey('hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _canResend
                        ? 'Didn\'t receive the code?'
                        : 'Resend code in ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
                  if (!_canResend)
                    Text(
                      '$_resendTimer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  if (!_canResend) Text('s'),
                  if (_canResend)
                    TextButton(
                      onPressed: _isLoading ? null : _handleResendOtp,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'Resend Code',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Edit phone number
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        context.go(RouteNames.register);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: context.palette.textMuted,
                ),
                child: Text(
                  'Use a different phone number',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
