// lib/presentation/screens/seller/earnings_screen.dart
// Modern seller earnings dashboard — wallet balance + order earnings + withdrawals.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/services/wallet_service.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../providers/auth_provider.dart';

final _sellerEarningsProvider = FutureProvider.autoDispose((ref) async {
  // Fetch wallet
  final wallet = await WalletService.fetchWallet();
  // Fetch seller orders for earnings breakdown
  final orders = await OrderService.fetchSellerOrders();

  double totalEarnings = 0;
  double pendingEarnings = 0;
  double completedEarnings = 0;
  final List<Map<String, dynamic>> earningsByOrder = [];

  for (final order in orders) {
    final earnings = order.sellerEarnings > 0
        ? order.sellerEarnings
        : (order.totalAmount - order.commissionAmount);
    totalEarnings += earnings;

    if (order.isCompleted || order.status == OrderStatus.delivered) {
      completedEarnings += earnings;
    } else if (order.isTrackingActive) {
      pendingEarnings += earnings;
    }

    earningsByOrder.add({
      'orderNumber': order.orderNumber,
      'productName': order.items.firstOrNull?.product.name ?? 'Products',
      'amount': earnings,
      'status': order.status.name,
      'date': order.createdAt,
      'isCompleted': order.isCompleted,
    });
  }

  final balance = (wallet['balance'] as num?)?.toDouble() ?? 0;
  final blocked = (wallet['blocked_balance'] as num?)?.toDouble() ?? 0;
  final available = (wallet['available_balance'] as num?)?.toDouble() ?? (balance - blocked);

  return _SellerEarningsData(
    totalEarnings: totalEarnings,
    availableBalance: available,
    pendingEarnings: pendingEarnings,
    completedEarnings: completedEarnings,
    ledgerBalance: balance,
    blockedBalance: blocked,
    earningsByOrder: earningsByOrder,
    wallet: wallet,
  );
});

class _SellerEarningsData {
  final double totalEarnings;
  final double availableBalance;
  final double pendingEarnings;
  final double completedEarnings;
  final double ledgerBalance;
  final double blockedBalance;
  final List<Map<String, dynamic>> earningsByOrder;
  final Map<String, dynamic> wallet;

  _SellerEarningsData({
    required this.totalEarnings,
    required this.availableBalance,
    required this.pendingEarnings,
    required this.completedEarnings,
    required this.ledgerBalance,
    required this.blockedBalance,
    required this.earningsByOrder,
    required this.wallet,
  });
}

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = ref.watch(authProvider);
    final isAuthed = auth is AsyncData && auth.value != null;
    final async = ref.watch(_sellerEarningsProvider);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, 'Earnings'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sellerDashboard),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_sellerEarningsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: p.textMuted,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Earnings History'),
          ],
        ),
      ),
      body: !isAuthed
          ? _buildUnauthenticated(context)
          : async.when(
              loading: () => const LoadingWidget(message: 'Loading earnings…'),
              error: (e, _) => _buildError(context, e),
              data: (data) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(_sellerEarningsProvider),
                color: AppColors.primary,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, data),
                    _buildHistoryTab(context, data),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUnauthenticated(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_outlined,
                  size: 50, color: p.iconMuted),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to view earnings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your wallet and earnings are protected',
              style: TextStyle(color: p.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(RouteNames.login),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load earnings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Helpers.errorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.invalidate(_sellerEarningsProvider),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, _SellerEarningsData data) {
    final p = context.palette;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(data.wallet['is_active'] != false),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(data.availableBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildBalanceDetail(
                      'Total Earned',
                      Formatters.formatCurrency(data.totalEarnings),
                    ),
                    const SizedBox(width: 24),
                    _buildBalanceDetail(
                      'Pending',
                      Formatters.formatCurrency(data.pendingEarnings),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          Text(
            'Earnings Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            children: [
              _StatCard(
                title: 'Completed',
                amount: Formatters.formatCurrency(data.completedEarnings),
                icon: Icons.check_circle_outlined,
                color: AppColors.success,
              ),
              _StatCard(
                title: 'Pending',
                amount: Formatters.formatCurrency(data.pendingEarnings),
                icon: Icons.schedule_outlined,
                color: AppColors.warning,
              ),
              _StatCard(
                title: 'Total Earnings',
                amount: Formatters.formatCurrency(data.totalEarnings),
                icon: Icons.trending_up_outlined,
                color: AppColors.primary,
              ),
              _StatCard(
                title: 'Ledger Balance',
                amount: Formatters.formatCurrency(data.ledgerBalance),
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Withdraw',
                  subtitle: 'Cash out to mobile money',
                  icon: Icons.arrow_upward_outlined,
                  color: AppColors.primary,
                  onTap: () => _showWithdrawSheet(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Deposit',
                  subtitle: 'Add funds to wallet',
                  icon: Icons.add_circle_outline,
                  color: const Color(0xFF10B981),
                  onTap: () => context.push(RouteNames.wallet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Transfer',
                  subtitle: 'Send to another user',
                  icon: Icons.send_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push(RouteNames.wallet),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Full History',
                  subtitle: 'View all transactions',
                  icon: Icons.history_outlined,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push(RouteNames.wallet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Order Earnings
          if (data.earningsByOrder.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Order Earnings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _tabController.animateTo(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...data.earningsByOrder.take(5).map((e) => _EarningsRow(
                  orderNumber: e['orderNumber'],
                  productName: e['productName'],
                  amount: e['amount'],
                  status: e['status'],
                  date: e['date'],
                  isCompleted: e['isCompleted'],
                )),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, _SellerEarningsData data) {
    final p = context.palette;

    if (data.earningsByOrder.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined,
                    size: 50, color: p.iconMuted),
              ),
              const SizedBox(height: 16),
              Text(
                'No earnings yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete orders to see earnings history',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'All Order Earnings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...data.earningsByOrder.map((e) => _EarningsRow(
              orderNumber: e['orderNumber'],
              productName: e['productName'],
              amount: e['amount'],
              status: e['status'],
              date: e['date'],
              isCompleted: e['isCompleted'],
            )),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.red.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        active ? 'Active' : 'Suspended',
        style: TextStyle(
          color: active ? Colors.green[100] : Colors.red[100],
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBalanceDetail(String label, String amount) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? destination;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    'Withdraw Earnings',
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
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Destination (MoMo number / bank)',
                      hintText: '024 123 4567 or bank details',
                      filled: true,
                      fillColor: context.palette.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => destination = v.trim().isEmpty ? null : v.trim(),
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
                    child: FilledButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          Helpers.showErrorToast('Enter a valid amount');
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await WalletService.requestWithdraw(
                            amount: amount,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            destination: destination,
                          );
                          if (!context.mounted) return;
                          Helpers.showSuccessToast(
                              'Withdrawal request submitted');
                          ref.invalidate(_sellerEarningsProvider);
                        } catch (e) {
                          if (context.mounted) {
                            Helpers.showErrorToast(e);
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Submit Withdrawal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: p.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  final String orderNumber;
  final String productName;
  final double amount;
  final String status;
  final DateTime date;
  final bool isCompleted;

  const _EarningsRow({
    required this.orderNumber,
    required this.productName,
    required this.amount,
    required this.status,
    required this.date,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.schedule,
                color: isCompleted ? AppColors.success : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatDate(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.textMuted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.formatCurrency(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatStatus(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    return status
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}