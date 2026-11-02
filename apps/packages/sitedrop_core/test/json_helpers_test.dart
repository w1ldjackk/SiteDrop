import 'package:flutter_test/flutter_test.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/core/utils/json_helpers.dart';

enum _Labeled {
  high('high');

  final String value;
  const _Labeled(this.value);

  String get displayName => 'High';
}

enum _Unlabeled {
  whatever;
}

void main() {
  group('listFromData', () {
    test('accepts a bare array (nested resource endpoints)', () {
      expect(
        JsonHelpers.listFromData([
          {'id': 1},
        ], const ['documents', 'data']),
        hasLength(1),
      );
    });

    test('accepts map-wrapped lists', () {
      expect(
        JsonHelpers.listFromData(
          {
            'documents': [
              {'id': 1},
            ],
          },
          const ['documents', 'data'],
        ),
        hasLength(1),
      );
    });

    test('returns [] for anything else, never throws', () {
      expect(JsonHelpers.listFromData(null), isEmpty);
      expect(JsonHelpers.listFromData('nope'), isEmpty);
      expect(JsonHelpers.listFromData({'a': 1}, const ['b']), isEmpty);
    });
  });

  group('dropdownLabel', () {
    test('title-cases raw strings (unit lists)', () {
      expect(DisplayNames.dropdownLabel('ton'), 'Ton');
      expect(DisplayNames.dropdownLabel('cubic_meter'), 'Cubic Meter');
    });

    test('resolves enum displayName dynamically', () {
      expect(
        DisplayNames.dropdownLabel(
          (_Labeled.values as List<dynamic>).first,
        ),
        'High',
      );
    });

    test('falls back to toString instead of throwing', () {
      expect(
        DisplayNames.dropdownLabel(
          (_Unlabeled.values as List<dynamic>).first,
        ),
        isNotEmpty,
      );
      expect(DisplayNames.dropdownLabel(null), '—');
    });
  });
}
