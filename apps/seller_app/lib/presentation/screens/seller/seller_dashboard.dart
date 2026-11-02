// lib/presentation/screens/seller/seller_dashboard.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../widgets/common/app_back_button.dart';

class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Seller Dashboard'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sellerDashboard, fallbackTabIndex: 0),
      ),
      body: const Center(child: Text('Seller Dashboard - Coming Soon')),
    );
  }
}
