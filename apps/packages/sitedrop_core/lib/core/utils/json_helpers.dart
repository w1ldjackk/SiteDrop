// lib/core/utils/json_helpers.dart
// Tolerant JSON parsing for backend payloads.
//
// Some rows carry double-encoded JSON (a JSON string where a List/Map is
// expected — e.g. seeders that json_encode values which Eloquent's `array`
// cast encodes again), empty PHP arrays (`[]`) where a map is expected, and
// numeric strings where numbers are expected. These helpers accept all of
// those shapes instead of throwing (a single throwing row used to nuke an
// entire list fetch into a fake-empty state).
library;

import 'dart:convert';

class JsonHelpers {
  /// Decode [v] if it is a JSON-encoded string, otherwise return as-is.
  /// Returns null for null/empty/undecodable input.
  static dynamic decodeIfString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      try {
        return jsonDecode(s);
      } catch (_) {
        return null;
      }
    }
    return v;
  }

  /// List of strings from a List, a JSON-encoded string, or a single value.
  static List<String> stringList(dynamic v) {
    var decoded = decodeIfString(v);
    if (decoded == null) return [];
    if (decoded is List) {
      return decoded
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final s = decoded.toString();
    return s.isEmpty ? [] : [s];
  }

  /// Raw list from a List or a JSON-encoded string. Never throws.
  static List<dynamic> anyList(dynamic v) {
    final decoded = decodeIfString(v);
    if (decoded is List) return decoded;
    return [];
  }

  /// `Map<String, String>` from a Map or JSON-encoded string. `[]` -> {}.
  static Map<String, String> stringMap(dynamic v) {
    final decoded = decodeIfString(v);
    if (decoded is Map) {
      return decoded.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    return {};
  }

  /// `Map<String, dynamic>?` from a Map or JSON-encoded string. `[]` -> null.
  static Map<String, dynamic>? dynamicMap(dynamic v) {
    final decoded = decodeIfString(v);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  /// Non-null `Map<String, dynamic>` ({} fallback).
  static Map<String, dynamic> dynamicMapOrEmpty(dynamic v) {
    return dynamicMap(v) ?? {};
  }

  /// bool from bool/num/string. Laravel booleans may arrive as 0/1.
  static bool boolean(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no' || s.isEmpty) return false;
    }
    return fallback;
  }

  /// double? from num/numeric string. Laravel decimals may serialize as strings.
  static double? toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  /// Extract a row list from an API `data` envelope that is inconsistently
  /// shaped: some endpoints return a bare JSON array, others an object with
  /// the rows under one of [keys]. Never throws; [] when unrecognized.
  static List<dynamic> listFromData(dynamic data, [List<String> keys = const []]) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in keys) {
        final v = data[key];
        if (v is List) return v;
      }
      // Single-key object whose value is the list (e.g. {"0": ...} never
      // happens; kept minimal on purpose).
    }
    return [];
  }
}
