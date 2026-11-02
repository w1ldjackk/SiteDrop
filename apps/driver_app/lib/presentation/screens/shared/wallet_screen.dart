// lib/presentation/screens/shared/wallet_screen.dart
// Shared wallet for buyer / seller / driver (and any signed-in role).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/services/wallet_service.dart';
import '../../providers/auth_provider.dart';
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
  Future<void> _deposit() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (GHS)'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      Helpers.showErrorToast('Enter a valid amount');
      return;
    }
    try {
      await WalletService.requestDeposit(amount: amount, note: noteCtrl.text.trim());
      Helpers.showSuccessToast('Deposit request submitted');
      ref.invalidate(walletInboxProvider);
    } catch (e) {
      Helpers.showErrorToast(e);
    }
  }

  Future<void> _withdraw() async {
    final amountCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (GHS)'),
            ),
            TextField(
              controller: destCtrl,
              decoration: const InputDecoration(labelText: 'MoMo / bank (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      Helpers.showErrorToast('Enter a valid amount');
      return;
    }
    try {
      await WalletService.requestWithdraw(
        amount: amount,
        destination: destCtrl.text.trim(),
      );
      Helpers.showSuccessToast('Withdrawal request submitted');
      ref.invalidate(walletInboxProvider);
    } catch (e) {
      Helpers.showErrorToast(e);
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
                                onPressed: _withdraw,
                                icon: const Icon(Icons.arrow_upward),
                                label: const Text('Withdraw'),
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
                                            (t['category']?.toString() ?? type),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (t['category'] != null)
                                            t['category'].toString(),
                                          status,
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
