// lib/data/models/product.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/api_constants.dart';

part 'product.g.dart';

@HiveType(typeId: 1)
class ProductModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String unit;

  @HiveField(4)
  final double price;

  @HiveField(5)
  final String category;

  @HiveField(6)
  final String subCategory;

  @HiveField(7)
  final String imageUrl;

  @HiveField(8)
  final List<String> images;

  @HiveField(9)
  final bool inStock;

  @HiveField(10)
  final int minQuantity;

  @HiveField(11)
  final int maxQuantity;

  @HiveField(12)
  final double rating;

  @HiveField(13)
  final int reviewCount;

  @HiveField(14)
  final String sku;

  @HiveField(15)
  final String sellerId;

  @HiveField(16)
  final String sellerName;

  @HiveField(17)
  final double deliveryFeePerKm;

  @HiveField(18)
  final int preparationTimeMinutes;

  @HiveField(19)
  final bool isFeatured;

  @HiveField(20)
  final bool isCodAvailable;

  @HiveField(21)
  final bool isDeliveryAvailable;

  @HiveField(22)
  final double weightKg;

  @HiveField(23)
  final int stockQuantity;

  @HiveField(24)
  final int ordersCount;

  @HiveField(25)
  final int viewsCount;

  @HiveField(26)
  final Map<String, dynamic>? specifications;

  @HiveField(27)
  final DateTime? createdAt;

  @HiveField(28)
  final DateTime? updatedAt;

  @HiveField(29)
  final String siteId;

  @HiveField(30)
  final String siteName;

  const ProductModel({
    required this.id,
    required this.name,
    this.description = '',
    this.unit = 'trip',
    this.price = 0,
    this.category = 'Materials',
    this.subCategory = '',
    this.imageUrl = '',
    this.images = const [],
    this.inStock = true,
    this.minQuantity = 1,
    this.maxQuantity = 100,
    this.rating = 0,
    this.reviewCount = 0,
    this.sku = '',
    this.sellerId = '',
    this.sellerName = '',
    this.deliveryFeePerKm = 0,
    this.preparationTimeMinutes = 0,
    this.isFeatured = false,
    this.isCodAvailable = true,
    this.isDeliveryAvailable = true,
    this.weightKg = 0,
    this.stockQuantity = 0,
    this.ordersCount = 0,
    this.viewsCount = 0,
    this.specifications,
    this.createdAt,
    this.updatedAt,
    this.siteId = '',
    this.siteName = '',
  });

  // Helper method to safely parse double values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to safely parse int values
  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }

  // Helper method to safely parse bool values
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) {
      return value == 1;
    }
    return false;
  }

  // Helper method to safely parse specifications
  static Map<String, dynamic>? _parseSpecifications(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        // Try to parse as JSON
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return null;
      } catch (e) {
        // If parsing fails, return null
        return null;
      }
    }
    return null;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Handle different API response structures
    final productData = json['product'] ?? json;

    // Get images - handle both List and String formats
    List<String> imagesList = [];
    String imageUrl = '';

    final imagesField = productData['images'];
    if (imagesField != null) {
      if (imagesField is List) {
        // Direct list of images
        imagesList = imagesField.map((e) => e.toString()).toList();
        if (imagesList.isNotEmpty) {
          imageUrl = imagesList.first;
        }
      } else if (imagesField is String) {
        // Try to parse as JSON string
        try {
          // Check if it's a JSON array string
          if (imagesField.startsWith('[') && imagesField.endsWith(']')) {
            final decoded = jsonDecode(imagesField) as List?;
            if (decoded != null) {
              imagesList = decoded.map((e) => e.toString()).toList();
              if (imagesList.isNotEmpty) {
                imageUrl = imagesList.first;
              }
            }
          } else {
            // Single image URL as string
            imageUrl = imagesField;
            if (imageUrl.isNotEmpty) {
              imagesList = [imageUrl];
            }
          }
        } catch (e) {
          // If parsing fails, treat as single URL
          imageUrl = imagesField;
          if (imageUrl.isNotEmpty) {
            imagesList = [imageUrl];
          }
        }
      }
    }

    // Fallback: check image_url field
    if (imageUrl.isEmpty) {
      imageUrl = productData['image_url']?.toString() ?? '';
      if (imageUrl.isNotEmpty && imagesList.isEmpty) {
        imagesList = [imageUrl];
      }
    }

    // Fallback: check if there's a single image in a string field
    if (imageUrl.isEmpty) {
      final imageField = productData['image']?.toString() ?? '';
      if (imageField.isNotEmpty) {
        imageUrl = imageField;
        imagesList = [imageUrl];
      }
    }

    // Get seller info
    final seller = productData['seller'] as Map<String, dynamic>?;

    // Get site info
    final sourceSite = productData['source_site'] as Map<String, dynamic>? ?? productData['sourceSite'] as Map<String, dynamic>?;
    final siteId = productData['site_id']?.toString() ?? sourceSite?['id']?.toString() ?? '';
    final siteName = sourceSite?['name']?.toString() ?? '';

    return ProductModel(
      id: productData['id']?.toString() ?? '',
      name: productData['name']?.toString() ?? '',
      description: productData['description']?.toString() ?? '',
      unit: productData['unit']?.toString() ?? 'trip',
      price: _parseDouble(
        productData['price_per_unit'] ?? productData['price'] ?? 0,
      ),
      category: productData['category']?.toString() ?? 'Materials',
      subCategory: productData['sub_category']?.toString() ?? '',
      imageUrl: ApiConstants.resolveAssetUrl(imageUrl),
      images: imagesList.map(ApiConstants.resolveAssetUrl).toList(),
      inStock:
          _parseBool(productData['is_available'] ?? true) &&
          _parseInt(productData['stock_quantity'] ?? 0) > 0,
      minQuantity: _parseInt(productData['minimum_order_quantity'] ?? 1),
      maxQuantity: _parseInt(productData['maximum_order_quantity'] ?? 100),
      rating: _parseDouble(
        productData['avg_rating'] ??
            productData['rating'] ??
            json['rating'] ??
            0,
      ),
      reviewCount: _parseInt(
        productData['total_reviews'] ??
            productData['reviews_count'] ??
            json['total_reviews'] ??
            0,
      ),
      sku: productData['sku']?.toString() ?? '',
      sellerId:
          productData['seller_id']?.toString() ??
          seller?['id']?.toString() ??
          '',
      sellerName: seller?['name']?.toString() ?? '',
      deliveryFeePerKm: _parseDouble(productData['delivery_fee_per_km'] ?? 0),
      preparationTimeMinutes: _parseInt(
        productData['preparation_time_minutes'] ?? 0,
      ),
      isFeatured: _parseBool(productData['is_featured'] ?? false),
      isCodAvailable: _parseBool(productData['is_cod_available'] ?? true),
      isDeliveryAvailable: _parseBool(
        productData['is_delivery_available'] ?? true,
      ),
      weightKg: _parseDouble(productData['weight_kg'] ?? 0),
      stockQuantity: _parseInt(productData['stock_quantity'] ?? 0),
      ordersCount: _parseInt(productData['orders_count'] ?? 0),
      viewsCount: _parseInt(productData['views_count'] ?? 0),
      specifications: _parseSpecifications(productData['specifications']),
      createdAt: productData['created_at'] != null
          ? DateTime.tryParse(productData['created_at'].toString())
          : null,
      updatedAt: productData['updated_at'] != null
          ? DateTime.tryParse(productData['updated_at'].toString())
          : null,
      siteId: siteId,
      siteName: siteName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unit': unit,
      'price_per_unit': price,
      'category': category,
      'sub_category': subCategory,
      'image_url': imageUrl,
      'images': images,
      'stock_quantity': stockQuantity,
      'minimum_order_quantity': minQuantity,
      'maximum_order_quantity': maxQuantity,
      'is_available': inStock,
      'is_featured': isFeatured,
      'is_cod_available': isCodAvailable,
      'is_delivery_available': isDeliveryAvailable,
      'delivery_fee_per_km': deliveryFeePerKm,
      'preparation_time_minutes': preparationTimeMinutes,
      'weight_kg': weightKg,
      'specifications': specifications,
      'sku': sku,
      'site_id': siteId,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? unit,
    double? price,
    String? category,
    String? subCategory,
    String? imageUrl,
    List<String>? images,
    bool? inStock,
    int? minQuantity,
    int? maxQuantity,
    double? rating,
    int? reviewCount,
    String? sku,
    String? sellerId,
    String? sellerName,
    double? deliveryFeePerKm,
    int? preparationTimeMinutes,
    bool? isFeatured,
    bool? isCodAvailable,
    bool? isDeliveryAvailable,
    double? weightKg,
    int? stockQuantity,
    int? ordersCount,
    int? viewsCount,
    Map<String, dynamic>? specifications,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? siteId,
    String? siteName,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      inStock: inStock ?? this.inStock,
      minQuantity: minQuantity ?? this.minQuantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      sku: sku ?? this.sku,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      deliveryFeePerKm: deliveryFeePerKm ?? this.deliveryFeePerKm,
      preparationTimeMinutes:
          preparationTimeMinutes ?? this.preparationTimeMinutes,
      isFeatured: isFeatured ?? this.isFeatured,
      isCodAvailable: isCodAvailable ?? this.isCodAvailable,
      isDeliveryAvailable: isDeliveryAvailable ?? this.isDeliveryAvailable,
      weightKg: weightKg ?? this.weightKg,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      ordersCount: ordersCount ?? this.ordersCount,
      viewsCount: viewsCount ?? this.viewsCount,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
    );
  }
}
