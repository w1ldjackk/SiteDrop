// lib/presentation/screens/profile/shared/terms_of_service_screen.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import '../../../widgets/common/app_back_button.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Terms of Service'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.divider, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Last Updated: December 2024',
                      style: TextStyle(color: context.palette.textMuted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    title: '1. Acceptance of Terms',
                    content:
                        'By using SiteDrop, you agree to comply with and be bound by these Terms of Service. If you do not agree to these terms, please do not use our services.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '2. User Accounts',
                    content:
                        'You must create an account to use our services. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '3. Buyer Terms',
                    content:
                        'As a buyer, you agree to provide accurate delivery information, make timely payments, and treat sellers and delivery personnel with respect. You are responsible for reviewing product details before ordering.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '4. Seller Terms',
                    content:
                        'As a seller, you agree to provide accurate product descriptions, maintain fair pricing, fulfill orders promptly, and provide quality products. You are responsible for complying with all applicable laws and regulations.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '5. Driver Terms',
                    content:
                        'As a driver, you agree to provide reliable delivery services, maintain professional conduct, and follow all traffic laws and regulations. You are responsible for ensuring deliveries are made safely and on time.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '6. Payments and Fees',
                    content:
                        'All payments are processed securely through our payment partners. Prices are shown in GHS and include applicable taxes. Platform fees and delivery charges will be clearly displayed at checkout.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '7. Cancellations and Refunds',
                    content:
                        'Orders can be cancelled within a specified timeframe. Refunds are processed according to our refund policy. Please contact support for any cancellation or refund requests.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '8. Prohibited Activities',
                    content:
                        'You agree not to use our platform for any unlawful purpose, to harass or abuse others, to interfere with the operation of our services, or to engage in fraudulent activities.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '9. Termination',
                    content:
                        'We reserve the right to suspend or terminate your account if you violate these terms or engage in any conduct that we deem harmful to our platform or other users.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '10. Changes to Terms',
                    content:
                        'We may update these terms from time to time. We will notify you of any significant changes by email or through our app. Continued use of our services constitutes acceptance of the updated terms.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '11. Contact Information',
                    content:
                        'If you have any questions about these Terms of Service, please contact us at legal@sitedrop.com or call +233 24 000 0000.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(fontSize: 14, color: context.palette.textMuted, height: 1.6),
        ),
      ],
    );
  }
}
