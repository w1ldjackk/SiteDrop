import 'package:flutter_test/flutter_test.dart';
import 'package:sitedrop_core/data/models/site.dart';

// Regression: AddEditSiteScreen._buildDropdown takes List<dynamic> and calls
// e.displayName. Extension members do NOT resolve through dynamic dispatch,
// so displayName must be an instance member of the enum (this crashed with
// NoSuchMethodError: 'displayName' on Instance of 'PriorityLevel').
void main() {
  test('PriorityLevel displayName resolves via dynamic dispatch', () {
    final List<dynamic> items = PriorityLevel.values;
    expect(items.map((e) => e.displayName as String).toList(), [
      'High',
      'Medium',
      'Low',
    ]);
  });

  test('SiteType/SiteStatus displayName resolve via dynamic dispatch', () {
    final List<dynamic> types = SiteType.values;
    expect(types.map((e) => e.displayName as String).toList(), isNotEmpty);
    final List<dynamic> statuses = SiteStatus.values;
    expect(statuses.map((e) => e.displayName as String).toList(), isNotEmpty);
  });
}
