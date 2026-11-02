// lib/core/utils/auth_gate.dart
// Guest → login/sign-up prompt for protected actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../presentation/providers/auth_provider.dart';

/// Helpers to guard actions that require a signed-in user.
class AuthGate {
  AuthGate._();

  static bool isAuthenticated(WidgetRef ref) {
    final auth = ref.read(authProvider);
    return auth is AsyncData && auth.value is AuthAuthenticated;
  }

  static bool isAuthenticatedFrom(AuthState? state) =>
      state is AuthAuthenticated;

  /// Returns `true` if the user may continue.
  /// If guest, shows a dialog and navigates to Login / Sign up when chosen.
  static Future<bool> require(
    BuildContext context,
    WidgetRef ref, {
    String action = 'continue',
  }) async {
    if (isAuthenticated(ref)) return true;
    if (!context.mounted) return false;

    final choice = await showAuthRequiredDialog(context, action: action);
    if (!context.mounted) return false;

    switch (choice) {
      case AuthPromptResult.login:
        context.push(RouteNames.login);
        break;
      case AuthPromptResult.signUp:
        context.push(RouteNames.register);
        break;
      case AuthPromptResult.dismiss:
      case null:
        break;
    }
    return false;
  }
}

enum AuthPromptResult { login, signUp, dismiss }

/// Theme-aware dialog: login / sign up / not now.
Future<AuthPromptResult?> showAuthRequiredDialog(
  BuildContext context, {
  String action = 'continue',
}) {
  final p = context.palette;

  return showDialog<AuthPromptResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign in required',
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Please log in or create an account to $action.',
          style: TextStyle(
            color: p.textMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(AuthPromptResult.dismiss),
            child: Text(
              'Not now',
              style: TextStyle(color: p.textMuted),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(AuthPromptResult.signUp),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign up'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(AuthPromptResult.login),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Log in'),
          ),
        ],
      );
    },
  );
}
