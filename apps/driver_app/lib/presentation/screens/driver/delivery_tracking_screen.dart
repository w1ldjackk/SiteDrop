// lib/presentation/screens/driver/delivery_tracking_screen.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../widgets/common/app_back_button.dart';

class DeliveryTrackingScreen extends StatelessWidget {
  final String deliveryId;

  const DeliveryTrackingScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Delivery Tracking'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.deliveryAssignments,
        ),
      ),
      body: Center(child: Text('Tracking delivery: $deliveryId')),
    );
  }
}
