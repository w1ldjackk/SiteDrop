// lib/presentation/screens/buyer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String paymentUrl;
  final double amount;
  final String reference;
  final String paymentMethod;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentUrl,
    required this.amount,
    required this.reference,
    required this.paymentMethod,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            Helpers.showErrorToast('Payment page error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check for success or failure callbacks
            final uri = Uri.parse(request.url);
            if (uri.path.contains('payment-success') ||
                uri.path.contains('success')) {
              _handlePaymentSuccess();
              return NavigationDecision.prevent;
            }
            if (uri.path.contains('payment-failed') ||
                uri.path.contains('failed') ||
                uri.path.contains('cancel')) {
              _handlePaymentFailure();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handlePaymentSuccess() {
    if (mounted) {
      Helpers.showSuccessToast('Payment successful!');
      context.go(RouteNames.orderTrackingWithId(widget.orderId));
    }
  }

  void _handlePaymentFailure() {
    if (mounted) {
      Helpers.showErrorToast('Payment failed. Please try again.');
      context.go(RouteNames.cart);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.surface,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Payment'),
        leading: AppBackButton(
          onPressed: () => context.go(RouteNames.checkout),
          fallbackRoute: RouteNames.checkout,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      Helpers.formatPrice(widget.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                ),
                const SizedBox(width: 12),
                Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reference',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    SelectableText(
                      widget.reference,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            const Positioned.fill(
              child: LoadingWidget(message: 'Loading payment…'),
            ),
        ],
      ),
    );
  }
}
