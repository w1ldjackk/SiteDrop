// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/config/app_config.dart';
import 'package:sitedrop_core/presentation/theme/auth_theme.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import '../../widgets/common/app_back_button.dart';
import 'package:sitedrop_core/presentation/widgets/forms/otp_pin_fields.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  /// Role is fixed per app binary (buyer/seller/driver) — no role picker.
  String get _selectedRole => AppConfig.roleName;

  String get _roleLabel => switch (AppConfig.roleName) {
        'seller' => 'Seller - Sell materials',
        'driver' => 'Driver - Deliver materials',
        _ => 'Buyer - Order materials',
      };
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  // OTP Flow
  final bool _otpSent = false;
  int _resendTimer = 60;
  bool _canResend = false;
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // (removed) Account-type picker: role is fixed per app binary.

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
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

  Future<void> _handleRegister() async {
    // Prevent multiple submissions
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      Helpers.showErrorToast('Please accept the terms and conditions');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final phone = Helpers.formatPhoneNumber(_phoneController.text.trim());
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final passwordConfirmation = _passwordConfirmationController.text.trim();

      final result = await ref
          .read(authProvider.notifier)
          .register(
            name: name,
            phone: phone,
            email: email.isEmpty ? null : email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            role: _selectedRole,
          );

      if (mounted) {
        result.when(
          data: (state) {
            if (state is AuthAuthenticated) {
              Helpers.showSuccessToast('Account created successfully!');
              // Navigate to OTP verification with phone
              context.go(RouteNames.otpVerification, extra: phone);
            }
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

  Future<void> _handleVerifyOtp() async {
    final otp = _otpCodeValue;
    if (otp.length < 6) {
      Helpers.showErrorToast('Please enter the complete verification code');
      return;
    }

    setState(() => _isLoading = true);

    final phone = Helpers.formatPhoneNumber(_phoneController.text.trim());
    final result = await ref
        .read(authProvider.notifier)
        .verifyOtp(phone: phone, code: otp);

    setState(() => _isLoading = false);

    if (mounted) {
      result.when(
        data: (state) {
          if (state is AuthAuthenticated) {
            Helpers.showSuccessToast('Phone verified successfully!');
            final user = state.user;
            // Navigate to appropriate dashboard
            if (user.isBuyer) {
              context.go(RouteNames.home);
            } else if (user.isSeller) {
              context.go(RouteNames.sellerDashboard);
            } else if (user.isDriver) {
              context.go(RouteNames.driverDashboard);
            } else {
              context.go(RouteNames.home);
            }
          }
        },
        error: (error, stack) {
          Helpers.showErrorToast(error.toString());
        },
        loading: () {},
      );
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendTimer = 60;
      _isLoading = true;
    });

    final phone = Helpers.formatPhoneNumber(_phoneController.text.trim());
    final result = await ref.read(authProvider.notifier).sendOtp(phone);

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    // Use local loading state
    final isLoading = _isLoading || authState is AsyncLoading<AuthState>;

    return Scaffold(
      backgroundColor: AuthTheme.scaffoldBg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button - Fixed navigation
                Row(
                  children: [
                    AppBackButton(
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
                    const Spacer(),
                    Text(
                      'Step 1 of 2',
                      style: TextStyle(
                        color: context.palette.iconMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Header
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join SiteDrop as a buyer, seller, or driver',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.palette.iconMuted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),

                // Full Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      enabled: !isLoading,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Enter your full name',
                        icon: Icons.person_outline,
                      ),
                      validator: Validators.required,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Phone Number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !isLoading && !_otpSent,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Enter your Ghana number (e.g., 024XXXXXXXX)',
                        icon: Icons.phone_outlined,
                      ),
                      validator: Validators.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email (Optional)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Address',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading && !_otpSent,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Optional email address',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          return Validators.email(value);
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role is fixed per app — display only, no picker.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.palette.inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.palette.border,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text(
                        _roleLabel,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Password
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !isLoading && !_otpSent,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Create a password (min 6 characters)',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: context.palette.iconMuted,
                          ),
                          onPressed: (isLoading || _otpSent)
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                        ),
                      ),
                      validator: Validators.password,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Confirm Password
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordConfirmationController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !isLoading && !_otpSent,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
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
                          onPressed: (isLoading || _otpSent)
                              ? null
                              : () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                        ),
                      ),
                      validator: (value) {
                        return Validators.passwordConfirmation(
                          value,
                          _passwordController.text,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Terms and Conditions
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (isLoading || _otpSent)
                          ? null
                          : (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                              });
                            },
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // OTP Section (shown after registration)
                if (_otpSent) ...[
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

                  // Verify OTP Button
                  PrimaryButton(
                    onPressed: _handleVerifyOtp,
                    isLoading: isLoading,
                    text: 'Verify & Continue',
                  ),
                ],

                // Register Button (shown before OTP sent)
                if (!_otpSent) ...[
                  PrimaryButton(
                    onPressed: _handleRegister,
                    isLoading: isLoading,
                    text: 'Create Account',
                  ),
                ],

                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.go(RouteNames.login);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'Sign In',
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

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.palette.textMuted, fontSize: 15),
      prefixIcon: Icon(icon, color: context.palette.textMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.palette.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.palette.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.palette.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
