// Dashboard metrics for seller home tab.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

class SellerDashboardStats {
  final double totalSales;
  final int pendingOrders;
  final int lowStockCount;
  final List<double> revenueByDay; // last 7 days, for simple bar chart

  const SellerDashboardStats({
    required this.totalSales,
    required this.pendingOrders,
    required this.lowStockCount,
    required this.revenueByDay,
  });

  static const empty = SellerDashboardStats(
    totalSales: 0,
    pendingOrders: 0,
    lowStockCount: 0,
    revenueByDay: [0, 0, 0, 0, 0, 0, 0],
  );
}

final sellerDashboardProvider =
    FutureProvider.autoDispose<SellerDashboardStats>((ref) async {
  // Hook real endpoints when available (OrderService / analytics).
  try {
    final products = await ProductService.fetchSellerProducts();
    final lowStock =
        products.where((p) => p.stockQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5)).length;

    int pending = 0;
    double sales = 0;
    try {
      final orders = await OrderService.fetchSellerOrders();
      pending = orders
          .where(
            (o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.confirmed ||
                o.status == OrderStatus.processing,
          )
          .length;
      sales = orders
          .where(
            (o) =>
                o.status == OrderStatus.completed ||
                o.status == OrderStatus.delivered,
          )
          .fold(0.0, (s, o) => s + o.totalAmount);
    } catch (e) {
      AppLogger.w('Seller orders for dashboard: $e');
    }

    // Placeholder trend until analytics API exists
    final trend = List<double>.generate(
      7,
      (i) => sales > 0 ? (sales / 7) * (0.6 + (i % 3) * 0.2) : 0,
    );

    return SellerDashboardStats(
      totalSales: sales,
      pendingOrders: pending,
      lowStockCount: lowStock,
      revenueByDay: trend,
    );
  } catch (e) {
    AppLogger.w('Seller dashboard load failed: $e');
    return SellerDashboardStats.empty;
  }
});
