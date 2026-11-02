// lib/presentation/screens/profile/shared/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../../widgets/common/app_back_button.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Help & Support'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.divider, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                _buildFaqTile(
                  context,
                  'How to place an order?',
                  '1. Browse products\n2. Add to cart\n3. Proceed to checkout\n4. Confirm delivery details\n5. Place order',
                ),
                _buildDivider(context),
                _buildFaqTile(
                  context,
                  'How to track my order?',
                  'Go to Order History, select your order, and view real-time tracking status.',
                ),
                _buildDivider(context),
                _buildFaqTile(
                  context,
                  'What payment methods are accepted?',
                  'We accept Mobile Money, Bank Transfer, and Cash on Delivery.',
                ),
                _buildDivider(context),
                _buildFaqTile(
                  context,
                  'How to contact a seller?',
                  'Go to product details and tap on "Contact Seller" button.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.divider, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                _buildContactTile(
                  context: context,
                  icon: Icons.phone_outlined,
                  title: 'Call Us',
                  subtitle: '+233 24 000 0000',
                  onTap: () {
                    launchUrl(Uri.parse('tel:+233240000000'));
                  },
                ),
                _buildDivider(context),
                _buildContactTile(
                  context: context,
                  icon: Icons.email_outlined,
                  title: 'Email Us',
                  subtitle: 'support@sitedrop.com',
                  onTap: () {
                    launchUrl(Uri.parse('mailto:support@sitedrop.com'));
                  },
                ),
                _buildDivider(context),
                _buildContactTile(
                  context: context,
                  icon: Icons.chat_outlined,
                  title: 'Live Chat',
                  subtitle: 'Chat with our support team',
                  onTap: () {
                    Helpers.showInfoToast('Live chat coming soon!');
                  },
                ),
                _buildDivider(context),
                _buildContactTile(
                  context: context,
                  icon: Icons.message_outlined,
                  title: 'WhatsApp',
                  subtitle: '+233 24 000 0000',
                  onTap: () {
                    launchUrl(Uri.parse('https://wa.me/233240000000'));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFaqTile(BuildContext context, String question, String answer) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.palette.textSecondary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: context.palette.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.palette.textMuted, fontSize: 13),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: context.palette.iconMuted,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      color: context.palette.divider,
      indent: 16,
      endIndent: 16,
    );
  }
}
