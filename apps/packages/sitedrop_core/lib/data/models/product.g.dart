// lib/data/models/product.g.dart
// This is a generated file. Do not edit manually.
// To regenerate, run: flutter pub run build_runner build --delete-conflicting-outputs

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 1;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String? ?? '',
      unit: fields[3] as String? ?? 'trip',
      price: _parseDouble(fields[4]),
      category: fields[5] as String? ?? 'Materials',
      subCategory: fields[6] as String? ?? '',
      imageUrl: fields[7] as String? ?? '',
      images: (fields[8] as List?)?.cast<String>() ?? const [],
      inStock: fields[9] as bool? ?? true,
      minQuantity: _parseInt(fields[10], 1),
      maxQuantity: _parseInt(fields[11], 100),
      rating: _parseDouble(fields[12]),
      reviewCount: _parseInt(fields[13], 0),
      sku: fields[14] as String? ?? '',
      sellerId: fields[15] as String? ?? '',
      sellerName: fields[16] as String? ?? '',
      deliveryFeePerKm: _parseDouble(fields[17]),
      preparationTimeMinutes: _parseInt(fields[18], 0),
      isFeatured: fields[19] as bool? ?? false,
      isCodAvailable: fields[20] as bool? ?? true,
      isDeliveryAvailable: fields[21] as bool? ?? true,
      weightKg: _parseDouble(fields[22]),
      stockQuantity: _parseInt(fields[23], 0),
      ordersCount: _parseInt(fields[24], 0),
      viewsCount: _parseInt(fields[25], 0),
      specifications: _parseSpecificationsFromReader(fields[26]),
      createdAt: fields[27] as DateTime?,
      updatedAt: fields[28] as DateTime?,
      siteId: fields[29] as String? ?? '',
      siteName: fields[30] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(31)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.subCategory)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.images)
      ..writeByte(9)
      ..write(obj.inStock)
      ..writeByte(10)
      ..write(obj.minQuantity)
      ..writeByte(11)
      ..write(obj.maxQuantity)
      ..writeByte(12)
      ..write(obj.rating)
      ..writeByte(13)
      ..write(obj.reviewCount)
      ..writeByte(14)
      ..write(obj.sku)
      ..writeByte(15)
      ..write(obj.sellerId)
      ..writeByte(16)
      ..write(obj.sellerName)
      ..writeByte(17)
      ..write(obj.deliveryFeePerKm)
      ..writeByte(18)
      ..write(obj.preparationTimeMinutes)
      ..writeByte(19)
      ..write(obj.isFeatured)
      ..writeByte(20)
      ..write(obj.isCodAvailable)
      ..writeByte(21)
      ..write(obj.isDeliveryAvailable)
      ..writeByte(22)
      ..write(obj.weightKg)
      ..writeByte(23)
      ..write(obj.stockQuantity)
      ..writeByte(24)
      ..write(obj.ordersCount)
      ..writeByte(25)
      ..write(obj.viewsCount)
      ..writeByte(26)
      ..write(obj.specifications)
      ..writeByte(27)
      ..write(obj.createdAt)
      ..writeByte(28)
      ..write(obj.updatedAt)
      ..writeByte(29)
      ..write(obj.siteId)
      ..writeByte(30)
      ..write(obj.siteName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// ProductModel helper methods
// **************************************************************************

// Helper methods for parsing values during deserialization
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
  return 0.0;
}

int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned) ?? defaultValue;
  }
  return defaultValue;
}

Map<String, dynamic>? _parseSpecificationsFromReader(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Invalid JSON / non-map payload — fall through to null.
    }
  }
  return null;
}
