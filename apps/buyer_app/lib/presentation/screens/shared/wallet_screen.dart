// lib/presentation/screens/shared/wallet_screen.dart
// Shared wallet for buyer / seller / driver (and any signed-in role).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/app_constants.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/payment.dart';
import 'package:sitedrop_core/data/models/payment_instrument.dart';
import 'package:sitedrop_core/data/services/instrument_service.dart';
import 'package:sitedrop_core/data/services/wallet_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/instruments_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

final walletInboxProvider =
    FutureProvider.autoDispose<
        ({Map<String, dynamic> wallet, List<Map<String, dynamic>> txs})>((ref) async {
  final authAsync = ref.watch(authProvider);
  final authState = authAsync.asData?.value;
  if (authState is! AuthAuthenticated) {
    return (wallet: <String, dynamic>{}, txs: <Map<String, dynamic>>[]);
  }
  return WalletService.fetchTransactions();
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  /// Deposit funded from a saved payment method/instrument.
  Future<void> _deposit() async {
    final instruments =
        await ref.read(instrumentsProvider.future).catchError((_) => const <PaymentInstrumentModel>[]);
    String? defaultMethod;
    try {
      defaultMethod = await ref.read(defaultPaymentMethodProvider.future);
    } catch (_) {}
    if (!mounted) return;

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    PaymentInstrumentModel? selectedInstrument;
    if (instruments.isNotEmpty) {
      selectedInstrument = instruments.where((i) => i.isDefault).firstOrNull ??
          instruments.first;
    }
    String selectedMethod = defaultMethod ?? AppConstants.paymentMethods.first;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.palette.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Deposit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (GHS)',
                      filled: true,
                      fillColor: context.palette.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pay with',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final si = selectedInstrument;
                      if (si == null) {
                        return const SizedBox.shrink();
                      }
                      return _PayOption(
                        title: si.headline,
                        subtitle:
                            '${si.subline} · Default account',
                        selected: true,
                        onTap: null,
                      );
                    },
                  ),
                  for (final m in AppConstants.paymentMethods)
                    Builder(
                      builder: (_) {
                        final si = selectedInstrument;
                        final matchesDefault = si != null &&
                            m == si.methodType.displayName;
                        return _PayOption(
                          title: m,
                          subtitle: matchesDefault
                              ? 'Default account above'
                              : null,
                          selected: si == null &&
                              m == selectedMethod,
                          onTap: () => setSheet(() {
                            selectedMethod = m;
                            selectedInstrument = null;
                          }),
                        );
                      },
                    ),
                  if (selectedInstrument != null)
                    TextButton(
                      onPressed: () => setSheet(
                        () => selectedInstrument = null,
                      ),
                      child: const Text('Use a different method'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      filled: true,
                      fillColor: context.palette.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      Helpers.showErrorToast('Enter a valid amount');
      return;
    }
    try {
      await WalletService.requestDeposit(
        amount: amount,
        note: noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim(),
        paymentMethod: selectedInstrument != null
            ? InstrumentService.guessMethodApi(selectedInstrument!)
            : (AppConstants.paymentMethodApiMap[selectedMethod] ??
                selectedMethod),
        instrumentId: selectedInstrument?.id,
      );
      if (!mounted) return;
      Helpers.showSuccessToast('Deposit request submitted');
      ref.invalidate(walletInboxProvider);
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    }
  }

  /// Internal transfer to another SiteDrop user (replaces withdrawals).
  Future<void> _transfer() async {
    final toCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Map<String, dynamic>? found;
    bool lookingUp = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> lookup() async {
            final q = toCtrl.text.trim();
            if (q.isEmpty) return;
            setSheet(() => lookingUp = true);
            try {
              final r =
                  await WalletService.lookupRecipient(q);
              if (!ctx.mounted) return;
              setSheet(() {
                found = r;
                lookingUp = false;
              });
              if (r == null) {
                Helpers.showErrorToast(
                  'No SiteDrop user found for that phone or email',
                );
              }
            } catch (_) {
              if (ctx.mounted) {
                setSheet(() => lookingUp = false);
              }
            }
          }

          final isSelf = found?['is_self'] == true;
          return Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.palette.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Transfer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send money instantly to any SiteDrop user',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: toCtrl,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Phone or email',
                              hintText: '024 123 4567',
                              filled: true,
                              fillColor:
                                  context.palette.inputFill,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) {
                              if (found != null) {
                                setSheet(() => found = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: lookingUp ? null : lookup,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: lookingUp
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Find'),
                        ),
                      ],
                    ),
                    if (found != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelf
                              ? AppColors.errorSurface
                              : AppColors.successSurface,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelf
                                  ? Icons.error_outline
                                  : Icons.check_circle,
                              color: isSelf
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSelf
                                    ? 'That is your own account'
                                    : '${found!['name']} · ${found!['phone'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (GHS)',
                        filled: true,
                        fillColor: context.palette.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        filled: true,
                        fillColor: context.palette.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (found == null || isSelf)
                            ? null
                            : () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Send transfer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      Helpers.showErrorToast('Enter a valid amount');
      return;
    }
    final name = found?['name']?.toString() ?? 'recipient';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Confirm transfer'),
        content: Text(
          'Send ${Helpers.formatPrice(amount)} to $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final data = await WalletService.transfer(
        recipient: toCtrl.text.trim(),
        amount: amount,
        note: noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim(),
      );
      if (!mounted) return;
      final msg = data['message']?.toString() ?? 'Transfer sent';
      Helpers.showSuccessToast(msg);
      ref.invalidate(walletInboxProvider);
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = ref.watch(authProvider);
    final isAuthed = auth is AsyncData && auth.value is AuthAuthenticated;
    final async = ref.watch(walletInboxProvider);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, 'Wallet'),
        leading: const AppBackButton(fallbackRoute: RouteNames.home),
      ),
      body: !isAuthed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sign in to view your wallet'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push(RouteNames.login),
                    child: const Text('Log in'),
                  ),
                ],
              ),
            )
          : async.when(
              loading: () => const LoadingWidget(message: 'Loading wallet…'),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Helpers.errorMessage(e)),
                    TextButton(
                      onPressed: () => ref.invalidate(walletInboxProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final w = data.wallet;
                final balance = (w['balance'] as num?)?.toDouble() ?? 0;
                final blocked = (w['blocked_balance'] as num?)?.toDouble() ?? 0;
                final available =
                    (w['available_balance'] as num?)?.toDouble() ??
                        (balance - blocked);
                final active = w['is_active'] != false;

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(walletInboxProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available balance',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              Helpers.formatPrice(available),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Ledger: ${Helpers.formatPrice(balance)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Flexible(
                                  child: Text(
                                    'Blocked: ${Helpers.formatPrice(blocked)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!active)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Wallet suspended — contact support',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (active)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _deposit,
                                icon: const Icon(Icons.add),
                                label: const Text('Deposit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _transfer,
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Transfer'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (data.txs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No transactions yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.textMuted),
                          ),
                        )
                      else
                        ...data.txs.map((t) {
                          final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                          final type = t['type']?.toString() ?? '';
                          final status = t['status']?.toString() ?? '';
                          final credit = type == 'credit';
                          final created = t['created_at']?.toString();
                          DateTime? dt;
                          if (created != null) dt = DateTime.tryParse(created);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  credit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: credit
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['description']?.toString() ??
                                            DisplayNames.transactionLabel(
                                              t['category']?.toString() ??
                                                  type,
                                            ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (t['category'] != null)
                                            DisplayNames.transactionLabel(
                                              t['category'].toString(),
                                            ),
                                          DisplayNames.paymentStatusLabel(
                                            status,
                                          ),
                                          if (dt != null)
                                            DateFormat.MMMd().add_jm().format(
                                                  dt.toLocal(),
                                                ),
                                        ].join(' · '),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${credit ? '+' : '-'}${Helpers.formatPrice(amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: credit
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Payment source row in the deposit sheet (saved account or method).
class _PayOption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _PayOption({
    required this.title,
    this.subtitle,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : context.palette.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? AppColors.primary
                      : context.palette.iconMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                context.palette.textMuted,
                          ),
                        ),
                    ],
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
