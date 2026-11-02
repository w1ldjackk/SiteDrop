import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sitedrop_core/app/theme/app_theme.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/config/app_config.dart';
import 'package:toastification/toastification.dart';

import '../core/listeners/app_listeners.dart';
import '../presentation/providers/locale_provider.dart';
import '../presentation/providers/service_providers.dart';
import '../presentation/providers/theme_provider.dart';
import 'routes/app_router.dart';

class SiteDropApp extends ConsumerWidget {
  const SiteDropApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppListeners.setup(ref);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final onlineAsync = ref.watch(connectivityOnlineProvider);
    final isOffline = onlineAsync.asData?.value == false;

    return ToastificationWrapper(
      child: MaterialApp.router(
        title: AppConfig.appDisplayName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: Locale(locale),
        supportedLocales: const [
          Locale('en'),
          Locale('fr'),
          Locale('tw'),
          Locale('ha'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
        builder: (context, child) {
          return Column(
            children: [
              if (isOffline)
                Material(
                  color: AppColors.warning,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, size: 16, color: AppColors.grey900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You are offline. Some actions may not work.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          );
        },
      ),
    );
  }
}
