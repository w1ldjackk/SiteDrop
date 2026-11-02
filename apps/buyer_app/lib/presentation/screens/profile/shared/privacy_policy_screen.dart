// lib/presentation/screens/profile/shared/privacy_policy_screen.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import '../../../widgets/common/app_back_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Privacy Policy'),
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
                      'Privacy Policy',
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
                    title: '1. Information We Collect',
                    content:
                        'We collect information you provide directly, such as your name, phone number, email address, delivery address, and payment information. We also collect information about your use of the app, including products viewed, orders placed, and interactions with sellers.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '2. How We Use Your Information',
                    content:
                        'We use your information to process orders, facilitate deliveries, communicate with you about your orders, improve our services, and personalize your experience on SiteDrop.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '3. Information Sharing',
                    content:
                        'We share your information with sellers to fulfill orders, delivery partners to deliver your items, and payment processors to complete transactions. We do not sell your personal information to third parties.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '4. Data Security',
                    content:
                        'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, disclosure, or destruction. All payment information is encrypted using industry-standard SSL technology.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '5. Your Rights',
                    content:
                        'You have the right to access, modify, or delete your personal information at any time. You can do this through your account settings or by contacting our support team.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '6. Cookies and Tracking',
                    content:
                        'We use cookies and similar tracking technologies to enhance your experience, analyze usage patterns, and deliver personalized content and advertising.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: '7. Contact Us',
                    content:
                        'If you have any questions about this Privacy Policy, please contact us at support@sitedrop.com or call +233 24 000 0000.',
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
