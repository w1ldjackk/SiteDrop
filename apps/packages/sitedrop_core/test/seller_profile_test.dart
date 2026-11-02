import 'package:flutter_test/flutter_test.dart';
import 'package:sitedrop_core/data/models/seller_profile.dart';

// Regression: the backend casts social_links/business_hours to PHP arrays,
// so empty values arrive as JSON `[]` (JSArray on web). Parsing must not
// throw, and verification docs must survive.
void main() {
  Map<String, dynamic> payload({
    Object? socialLinks = const [],
    Object? businessHours = const [],
  }) {
    return {
      'id': '1',
      'user_id': '7',
      'business_name': 'Accra Building Supplies',
      'business_type': 'supplier',
      'status': 'pending',
      'email_verified': 1,
      'commission_rate': '10.00',
      'minimum_order_amount': '0',
      'delivery_radius_km': '50',
      'service_areas': [],
      'verification_documents': [
        {
          'type': 'registration',
          'url': '/assets/docs/seller-documents/cac.pdf',
          'uploaded_at': '2026-09-20T10:00:00Z',
        },
      ],
      'social_links': socialLinks,
      'business_hours': businessHours,
      'created_at': '2026-09-20T10:00:00Z',
      'updated_at': '2026-09-20T10:00:00Z',
    };
  }

  test('parses empty-array social_links/business_hours with docs intact', () {
    final profile = SellerProfileModel.fromJson(payload());
    expect(profile.businessName, 'Accra Building Supplies');
    expect(profile.socialLinks, isEmpty);
    expect(profile.businessHours, isNull);
    expect(profile.verificationEntries, hasLength(1));
    expect(profile.verificationEntries.first.type, 'registration');
    expect(profile.emailVerified, isTrue);
    expect(profile.commissionRate, 10.0);
  });

  test('parses populated maps as before', () {
    final profile = SellerProfileModel.fromJson(
      payload(
        socialLinks: {'facebook': 'https://facebook.com/x'},
        businessHours: {
          'notes': 'Mon-Fri 8-17',
        },
      ),
    );
    expect(profile.socialLinks['facebook'], 'https://facebook.com/x');
    expect(profile.businessHours?['notes'], 'Mon-Fri 8-17');
    expect(profile.verificationEntries, hasLength(1));
  });
}
