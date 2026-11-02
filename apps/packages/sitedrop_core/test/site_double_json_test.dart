import 'package:flutter_test/flutter_test.dart';
import 'package:sitedrop_core/data/models/site.dart';
import 'package:sitedrop_core/data/models/site_staff.dart';

// Regression: seeded rows were double-encoded (json_encode into Eloquent
// `array` casts), so the API emitted JSON *strings* for coordinates,
// site_photos, materials_needed, shift_schedule, certifications, skills.
// `as List`/`as Map` casts threw, one bad row nuked the whole list fetch
// into "No sites yet". fromJson must accept both shapes.
void main() {
  Map<String, dynamic> siteRow({
    Object? coordinates = const {'lat': 5.6037, 'lng': -0.187},
    Object? sitePhotos = const ['/assets/img/seed/site-accra-1.png'],
    Object? materialsNeeded = const [
      {'material': 'sand', 'quantity': 500, 'unit': 'tons'},
    ],
    Object? sizeSqMeters = 2500,
    Object? budget = 2500000,
  }) {
    return {
      'id': 1,
      'user_id': 5,
      'name': 'Accra Central Construction Site',
      'address': '123 Liberation Road, Accra Central, Ghana',
      'coordinates': coordinates,
      'site_photos': sitePhotos,
      'site_type': 'construction',
      'status': 'active',
      'size_sq_meters': sizeSqMeters,
      'budget': budget,
      'materials_needed': materialsNeeded,
      'priority_level': 'high',
      'site_code': 'SITE2024ACC001',
      'created_at': '2026-09-20T10:00:00Z',
      'updated_at': '2026-09-20T10:00:00Z',
    };
  }

  test('parses clean API shapes', () {
    final site = SiteModel.fromJson(siteRow());
    expect(site.name, 'Accra Central Construction Site');
    expect(site.coordinates?.latitude, 5.6037);
    expect(site.sitePhotos, hasLength(1));
    expect(site.materialsNeeded, hasLength(1));
    expect(site.sizeSqMeters, 2500);
  });

  test('parses double-encoded string fields (seeded rows)', () {
    final site = SiteModel.fromJson(
      siteRow(
        coordinates: '{"lat":5.6037,"lng":-0.187}',
        sitePhotos: '["/assets/img/seed/site-accra-1.png"]',
        materialsNeeded:
            '[{"material":"sand","quantity":500,"unit":"tons"}]',
        sizeSqMeters: '2500.00',
        budget: '2500000.00',
      ),
    );
    expect(site.name, 'Accra Central Construction Site');
    expect(site.coordinates?.latitude, 5.6037);
    expect(site.coordinates?.longitude, -0.187);
    expect(site.sitePhotos, hasLength(1));
    expect(site.materialsNeeded, hasLength(1));
    expect(site.sizeSqMeters, 2500);
    expect(site.budget, 2500000);
  });

  test('parses null/empty shapes (app-created rows)', () {
    final site = SiteModel.fromJson(
      siteRow(
        coordinates: null,
        sitePhotos: null,
        materialsNeeded: null,
        sizeSqMeters: null,
        budget: null,
      ),
    );
    expect(site.coordinates, isNull);
    expect(site.sitePhotos, isEmpty);
    expect(site.materialsNeeded, isEmpty);
    expect(site.sizeSqMeters, isNull);
  });

  test('parses double-encoded staff fields', () {
    final staff = SiteStaffModel.fromJson({
      'id': 1,
      'site_id': 1,
      'user_id': 5,
      'role': 'site_manager',
      'position': 'Manager',
      'start_date': '2026-09-20T10:00:00Z',
      'is_active': 1,
      'shift_schedule': '{"monday_to_friday": "08:00-17:00"}',
      'contact_emergency': '{"name": "Emergency", "phone": "233501234599"}',
      'certifications': '["Project Management", "Safety Officer"]',
      'skills': '["Leadership"]',
      'performance_rating': '4.5',
      'created_at': '2026-09-20T10:00:00Z',
      'updated_at': '2026-09-20T10:00:00Z',
    });
    expect(staff.isActive, isTrue);
    expect(staff.shiftSchedule?['monday_to_friday'], '08:00-17:00');
    expect(
      staff.contactEmergency?['phone'],
      '233501234599',
    );
    expect(staff.certifications, hasLength(2));
    expect(staff.skills, ['Leadership']);
    expect(staff.performanceRating, 4.5);
  });
}
