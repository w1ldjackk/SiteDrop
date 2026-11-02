// lib/presentation/screens/auth/login_screen.dart
// The full updated version with correct OTP methods

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/validators.dart';
import '../../../gen/assets.gen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/main_tab_provider.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/social_button.dart';
import '../../widgets/common/app_back_button.dart';
import 'package:sitedrop_core/presentation/widgets/forms/otp_pin_fields.dart';
import 'package:sitedrop_core/presentation/theme/auth_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isOtpLogin = false;
  bool _otpSent = false;
  bool _otpError = false;
  int _resendTimer = 60;
  bool _canResend = false;
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCodeValue {
    return _otpControllers.map((c) => c.text).join();
  }

  void _onOtpChanged(String code) {
    if (_otpError && mounted) {
      setState(() => _otpError = false);
    }
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

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _otpSent = false;
    });

    final login = _loginController.text.trim();

    try {
      // Use sendOtpForLogin from provider
      final result = await ref
          .read(authProvider.notifier)
          .sendOtpForLogin(login);

      if (mounted) {
        result.when(
          data: (_) {
            setState(() {
              _otpSent = true;
              _resendTimer = 60;
              _canResend = false;
            });
            Helpers.showSuccessToast('OTP sent successfully!');
            _startTimer();
            // Auto-focus first OTP field
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _otpFocusNodes[0].requestFocus();
            });
            setState(() {
              _isLoading = false;
            });
          },
          error: (error, stack) {
            Helpers.showErrorToast(error.toString());
            setState(() {
              _isLoading = false;
            });
          },
          loading: () {},
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(e.toString());
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerifyOtp([String? completedCode]) async {
    if (_isLoading) return;
    final otp = (completedCode ?? _otpCodeValue).trim();
    if (otp.length < 6) {
      Helpers.showErrorToast('Please enter the complete verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = false;
    });

    final login = _loginController.text.trim();
    // Use verifyOtpForLogin from provider
    final result = await ref
        .read(authProvider.notifier)
        .verifyOtpForLogin(phone: login, code: otp);

    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.hasError) {
      Helpers.showErrorToast(result.error.toString());
      if (mounted) setState(() => _otpError = true);
      return;
    }

    final authState = result.asData?.value;
    if (authState is AuthAuthenticated ||
        ref.read(authProvider).asData?.value is AuthAuthenticated) {
      Helpers.showSuccessToast('Login successful!');
      _goHome();
      return;
    }

    Helpers.showErrorToast('Login failed. Please try again.');
    if (mounted) setState(() => _otpError = true);
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendTimer = 60;
      _isLoading = true;
      _otpError = false;
    });
    for (final c in _otpControllers) {
      c.clear();
    }

    final login = _loginController.text.trim();
    final result = await ref.read(authProvider.notifier).sendOtpForLogin(login);

    setState(() => _isLoading = false);

    if (mounted) {
      result.when(
        data: (_) {
          Helpers.showSuccessToast('OTP resent successfully!');
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
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ref
          .read(authProvider.notifier)
          .login(login: login, password: password, remember: _rememberMe);

      if (!mounted) return;

      if (result.hasError) {
        Helpers.showErrorToast(result.error.toString());
        setState(() => _isLoading = false);
        return;
      }

      final authState = result.asData?.value;
      if (authState is AuthAuthenticated) {
        Helpers.showSuccessToast('Login successful!');
        _goHome();
        return;
      }

      // Fallback: read latest provider state after login
      final latest = ref.read(authProvider).asData?.value;
      if (latest is AuthAuthenticated) {
        Helpers.showSuccessToast('Login successful!');
        _goHome();
        return;
      }

      setState(() => _isLoading = false);
      Helpers.showErrorToast('Login failed. Please try again.');
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(e.toString());
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goHome() {
    if (!mounted) return;
    ref.read(mainTabIndexProvider.notifier).setIndex(0);
    context.go(RouteNames.home);
  }

  void _toggleLoginMethod() {
    setState(() {
      _isOtpLogin = !_isOtpLogin;
      _otpSent = false;
      _otpError = false;
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _resendTimer = 60;
      _canResend = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLoading || authState is AsyncLoading<AuthState>;

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
                // Back → marketplace home (guest browse)
                AppBackButton(
                  fallbackRoute: RouteNames.home,
                  margin: EdgeInsets.zero,
                  onPressed: () {
                    ref.read(mainTabIndexProvider.notifier).setIndex(0);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.home);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Logo and Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.logo,
                          width: 80,
                          height: 80,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOtpLogin
                            ? 'Sign in with OTP'
                            : 'Sign in to continue to SiteDrop',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.palette.iconMuted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Login Field (Phone/Email)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOtpLogin ? 'Phone Number' : 'Phone or Email',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _loginController,
                      keyboardType: _isOtpLogin
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      enabled: !isLoading && !_otpSent,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: _isOtpLogin
                            ? 'Enter your phone number'
                            : 'Enter phone number or email',
                        hintStyle: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          _isOtpLogin
                              ? Icons.phone_outlined
                              : Icons.person_outline,
                          color: context.palette.iconMuted,
                        ),
                        filled: true,
                        fillColor: context.palette.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.palette.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.palette.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return _isOtpLogin
                              ? 'Please enter your phone number'
                              : 'Please enter your phone or email';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Password Field (only for normal login)
                if (!_isOtpLogin) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.palette.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !isLoading,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(
                            color: context.palette.textMuted,
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: context.palette.iconMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: context.palette.iconMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: context.palette.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.palette.border,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.palette.border,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.error,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: Validators.password,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Remember Me & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Text(
                            'Remember me',
                            style: TextStyle(
                              color: context.palette.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                context.go(RouteNames.forgotPassword);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // OTP Section — auto-verifies once all 6 digits are in.
                if (_isOtpLogin && _otpSent) ...[
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter 6-digit OTP',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.palette.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      OtpPinFields(
                        controllers: _otpControllers,
                        focusNodes: _otpFocusNodes,
                        enabled: !isLoading,
                        hasError: _otpError,
                        onChanged: _onOtpChanged,
                        onCompleted: _handleVerifyOtp,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: isLoading
                            ? Text(
                                'Verifying code…',
                                style: TextStyle(
                                  color: context.palette.textMuted,
                                  fontSize: 13,
                                ),
                              )
                            : Text(
                                'Code is verified automatically',
                                style: TextStyle(
                                  color: context.palette.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Resend timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _canResend
                            ? 'Didn\'t receive the code?'
                            : 'Resend code in ',
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      if (!_canResend)
                        Text(
                          '$_resendTimer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      if (!_canResend)
                        Text('s', style: TextStyle(fontSize: 14)),
                      if (_canResend)
                        TextButton(
                          onPressed: isLoading ? null : _handleResendOtp,
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
                  const SizedBox(height: 24),
                ],

                // Login/OTP Button
                if (!_isOtpLogin || !_otpSent) ...[
                  const SizedBox(height: 24),

                  // Login Button or Send OTP Button
                  PrimaryButton(
                    onPressed: _isOtpLogin ? _handleSendOtp : _handleLogin,
                    isLoading: isLoading,
                    text: _isOtpLogin ? 'Send OTP' : 'Sign In',
                  ),
                ],

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: context.palette.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          color: context.palette.iconMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: context.palette.divider)),
                  ],
                ),
                const SizedBox(height: 20),

                // Social Login Buttons (Font Awesome brands)
                Row(
                  children: [
                    Expanded(
                      child: SocialButton.google(
                        onPressed: isLoading
                            ? null
                            : () {
                                Helpers.showInfoToast(
                                  'Google login coming soon',
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SocialButton.apple(
                        onPressed: isLoading
                            ? null
                            : () {
                                Helpers.showInfoToast(
                                  'Apple login coming soon',
                                );
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toggle Login Method
                Center(
                  child: TextButton(
                    onPressed: isLoading ? null : _toggleLoginMethod,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      _isOtpLogin
                          ? 'Sign in with password instead'
                          : 'Sign in with OTP instead',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.go(RouteNames.register);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
