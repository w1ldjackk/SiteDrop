// lib/presentation/screens/profile/user/payment_methods_screen.dart
// Payment Methods hub: default method (synced), all available methods,
// and recent payments. Tapping a method sets it as the checkout default.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/app_constants.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/payment.dart';
import 'package:sitedrop_core/data/models/payment_instrument.dart';
import 'package:sitedrop_core/data/services/instrument_service.dart';
import '../../../providers/instruments_provider.dart';
import '../../../providers/payment_provider.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/payments/instrument_sheets.dart';

/// Friendly subtitles per method type.
String _methodSubtitle(PaymentMethodType type) {
  switch (type) {
    case PaymentMethodType.mobileMoney:
      return 'MTN, Vodafone & AirtelTigo';
    case PaymentMethodType.card:
      return 'Secure card payments via Paystack';
    case PaymentMethodType.bankTransfer:
      return 'Transfer to escrow account';
    case PaymentMethodType.wallet:
      return 'Pay with your SiteDrop balance';
    case PaymentMethodType.cash:
      return 'Pay when you receive';
  }
}

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsListProvider);
    final defaultAsync = ref.watch(defaultPaymentMethodProvider);
    final historyAsync = ref.watch(paymentHistoryProvider);
    final instrumentsAsync = ref.watch(instrumentsProvider);
    final currentDefault = defaultAsync.asData?.value;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: appBarTitle(context, 'Payment Methods'),
        backgroundColor: context.palette.surface,
        elevation: 0,
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(paymentMethodsListProvider);
              ref.invalidate(defaultPaymentMethodProvider);
              ref.invalidate(paymentHistoryProvider);
              ref.invalidate(instrumentsProvider);
              ref.invalidate(defaultInstrumentProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentMethodsListProvider);
          ref.invalidate(defaultPaymentMethodProvider);
          ref.invalidate(paymentHistoryProvider);
          ref.invalidate(instrumentsProvider);
          ref.invalidate(defaultInstrumentProvider);
          try {
            await Future.wait([
              ref.read(paymentMethodsListProvider.future),
              ref.read(defaultPaymentMethodProvider.future),
              ref.read(paymentHistoryProvider.future),
              ref.read(instrumentsProvider.future),
            ]);
          } catch (_) {}
        },
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(context, 'My accounts'),
                FilledButton.icon(
                  onPressed: () => showAddInstrumentSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            instrumentsAsync.when(
              data: (instruments) => instruments.isEmpty
                  ? _emptyBox(
                      context,
                      Icons.account_balance_wallet_outlined,
                      'Save your MoMo number, card or bank account for faster checkout',
                    )
                  : Column(
                      children: [
                        for (var i = 0;
                            i < instruments.length;
                            i++) ...[
                          _InstrumentTile(
                            instrument: instruments[i],
                            onTap: () => _instrumentActions(
                              context,
                              ref,
                              instruments[i],
                            ),
                          ),
                          if (i < instruments.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
              loading: () => const SizedBox(
                height: 72,
                child: LoadingWidget.compact(),
              ),
              error: (e, _) => _emptyBox(
                context,
                Icons.account_balance_wallet_outlined,
                Helpers.errorMessage(e),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'All methods'),
            const SizedBox(height: 4),
            Text(
              'Tap a method to make it your default',
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            methodsAsync.when(
              data: (methods) =>
                  _buildMethodList(context, ref, methods, currentDefault),
              loading: () => const SizedBox(
                height: 160,
                child: LoadingWidget.compact(),
              ),
              error: (e, _) => _buildMethodList(
                context,
                ref,
                const [],
                currentDefault,
                error: e,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(context, 'Recent payments'),
                TextButton(
                  onPressed: () =>
                      context.push(RouteNames.orderHistory),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(64, 44),
                  ),
                  child: const Text('View orders'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              data: (history) => history.isEmpty
                  ? _emptyBox(
                      context,
                      Icons.receipt_long_outlined,
                      'No payments yet',
                    )
                  : Column(
                      children: [
                        for (final p in history.take(5)) ...[
                          _PaymentRow(payment: p),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
              loading: () => const SizedBox(
                height: 80,
                child: LoadingWidget.compact(),
              ),
              error: (_, _) => _emptyBox(
                context,
                Icons.receipt_long_outlined,
                'Payment history unavailable',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: context.palette.textPrimary,
      ),
    );
  }

  Widget _buildMethodList(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> methods,
    String? currentDefault, {
    Object? error,
  }) {
    // Server list first (authoritative), then any local-only methods.
    final seen = <String>{};
    final tiles = <Widget>[];
    for (final m in methods) {
      final api = (m['type']?.toString() ??
              m['method']?.toString() ??
              m['id']?.toString() ??
              '')
          .trim();
      final type = PaymentMethodTypeX.fromApi(api);
      final title = (m['name']?.toString() ??
              m['label']?.toString() ??
              type.displayName)
          .trim();
      if (title.isEmpty || !seen.add(title)) continue;
      tiles.add(
        _MethodTile(
          title: title,
          subtitle: (m['description']?.toString() ??
                  m['subtitle']?.toString() ??
                  _methodSubtitle(type))
              .trim(),
          type: type,
          isDefault: title == currentDefault,
          onTap: () =>
              _setDefault(context, ref, title, currentDefault),
        ),
      );
    }
    for (final name in AppConstants.paymentMethods) {
      if (seen.contains(name)) continue;
      final type = PaymentMethodTypeX.fromApi(
        AppConstants.paymentMethodApiMap[name],
      );
      tiles.add(
        _MethodTile(
          title: name,
          subtitle: _methodSubtitle(type),
          type: type,
          isDefault: name == currentDefault,
          onTap: () =>
              _setDefault(context, ref, name, currentDefault),
        ),
      );
    }
    if (tiles.isEmpty) {
      return _emptyBox(
        context,
        Icons.payments_outlined,
        error == null
            ? 'No payment methods available'
            : Helpers.errorMessage(error),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          tiles[i],
          if (i < tiles.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _setDefault(
    BuildContext context,
    WidgetRef ref,
    String title,
    String? current,
  ) async {
    if (title == current) return;
    await saveDefaultPaymentMethod(ref, title);
    if (context.mounted) {
      Helpers.showSuccessToast('Default set to $title');
    }
  }

  void _instrumentActions(
    BuildContext context,
    WidgetRef ref,
    PaymentInstrumentModel instrument,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (!instrument.isDefault)
                ListTile(
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                  ),
                  title: const Text('Set as default'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final (ok, message) =
                        await InstrumentService.setDefault(
                      instrument.id,
                    );
                    // Keep the method-level default in sync for checkout.
                    await saveDefaultPaymentMethod(
                      ref,
                      instrument.methodType.displayName,
                    );
                    ref.invalidate(instrumentsProvider);
                    ref.invalidate(defaultInstrumentProvider);
                    if (context.mounted) {
                      if (ok) {
                        Helpers.showSuccessToast(message);
                      } else {
                        Helpers.showErrorToast(message);
                      }
                    }
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: context.palette.icon,
                ),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  showInstrumentFormSheet(
                    context,
                    instrument.type,
                    existing: instrument,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: Text(
                  'Remove',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Remove this account?'),
                      content: Text(instrument.headline),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(d, false),
                          child: const Text('Keep'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(d, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  final (ok, message) =
                      await InstrumentService.remove(instrument.id);
                  ref.invalidate(instrumentsProvider);
                  ref.invalidate(defaultInstrumentProvider);
                  if (context.mounted) {
                    if (ok) {
                      Helpers.showSuccessToast(message);
                    } else {
                      Helpers.showErrorToast(message);
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(BuildContext context, IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: context.palette.iconMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentTile extends StatelessWidget {
  final PaymentInstrumentModel instrument;
  final VoidCallback onTap;

  const _InstrumentTile({
    required this.instrument,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i = instrument;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: i.isDefault
              ? AppColors.primary.withValues(alpha: 0.5)
              : context.palette.divider,
          width: i.isDefault ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.palette.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: FaIcon(
              i.methodType.faIcon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                i.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (i.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          [
            if (i.label?.trim().isNotEmpty == true) i.label!.trim(),
            i.subline,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: context.palette.textMuted,
          ),
        ),
        trailing: Icon(
          Icons.more_vert,
          color: context.palette.iconMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {  final String title;
  final String subtitle;
  final PaymentMethodType type;
  final bool isDefault;
  final VoidCallback? onTap;

  const _MethodTile({
    required this.title,
    required this.subtitle,
    required this.type,
    this.isDefault = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDefault
              ? AppColors.primary.withValues(alpha: 0.5)
              : context.palette.divider,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.palette.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: FaIcon(
              type.faIcon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isDefault)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: context.palette.textMuted,
          ),
        ),
        trailing: isDefault
            ? Icon(Icons.check_circle, color: AppColors.primary)
            : Icon(
                Icons.circle_outlined,
                color: context.palette.iconMuted,
              ),
        onTap: onTap,
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentModel payment;

  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final ok = payment.isSuccessful;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (ok ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              ok ? Icons.check_circle_outline : Icons.schedule_outlined,
              color: ok ? AppColors.success : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentMethod.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    payment.status.displayName,
                    if (payment.createdAt != null)
                      Helpers.formatDate(payment.createdAt!),
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Helpers.formatPrice(payment.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
