// lib/data/models/cart_item.dart
import 'dart:convert';
import '../../core/constants/api_constants.dart';
import 'product.dart';

class CartItemModel {
  final String? id;
  final String? productId;
  final ProductModel product;
  final int quantity;
  final double price;
  final double subtotal;
  final String? sellerId;
  final String? sellerName;
  final int? maxQuantity;
  final String? unit;
  final String? productName;
  final String? productImage;

  const CartItemModel({
    this.id,
    this.productId,
    required this.product,
    required this.quantity,
    required this.price,
    this.subtotal = 0,
    this.sellerId,
    this.sellerName,
    this.maxQuantity,
    this.unit,
    this.productName,
    this.productImage,
  });

  double get lineTotal => price * quantity;

  CartItemModel copyWith({
    String? id,
    String? productId,
    ProductModel? product,
    int? quantity,
    double? price,
    double? subtotal,
    String? sellerId,
    String? sellerName,
    int? maxQuantity,
    String? unit,
    String? productName,
    String? productImage,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      unit: unit ?? this.unit,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
    );
  }

  // ============================================================
  // HELPERS TO PARSE NUMERIC VALUES FROM STRING OR NUM
  // ============================================================
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ============================================================
  // FROM JSON
  // ============================================================
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    // Try to get product from nested or direct data
    ProductModel product;

    if (json['product'] != null && json['product'] is Map<String, dynamic>) {
      product = ProductModel.fromJson(json['product'] as Map<String, dynamic>);
    } else {
      // Build product from cart item data
      String imageUrl = '';
      final imageField = json['product_image'];
      if (imageField != null) {
        if (imageField is String) {
          if (imageField.startsWith('[') && imageField.endsWith(']')) {
            try {
              final decoded = jsonDecode(imageField) as List?;
              if (decoded != null && decoded.isNotEmpty) {
                imageUrl = decoded.first.toString();
              }
            } catch (e) {
              imageUrl = imageField != '[' ? imageField : '';
            }
          } else {
            imageUrl = imageField;
          }
        } else if (imageField is List && imageField.isNotEmpty) {
          imageUrl = imageField.first.toString();
        }
      }

      if (imageUrl.isEmpty || imageUrl == '[') {
        imageUrl =
            'https://via.placeholder.com/400x400/1A8E5A/FFFFFF?text=No+Image';
      }
      imageUrl = ApiConstants.resolveAssetUrl(imageUrl);

      product = ProductModel(
        id: json['product_id']?.toString() ?? '',
        name: json['product_name']?.toString() ?? 'Unknown Product',
        price: _parseDouble(json['price']),
        unit: json['unit']?.toString() ?? 'piece',
        category: '',
        description: '',
        imageUrl: imageUrl,
        images: imageUrl.isNotEmpty ? [imageUrl] : [],
        inStock: true,
        minQuantity: 1,
        maxQuantity: _parseInt(json['max_quantity']) > 0
            ? _parseInt(json['max_quantity'])
            : 100,
        rating: 0,
        reviewCount: 0,
        sku: '',
        sellerId: json['seller_id']?.toString() ?? '',
        sellerName: json['seller_name']?.toString() ?? '',
        deliveryFeePerKm: 0,
        preparationTimeMinutes: 0,
        isFeatured: false,
        isCodAvailable: true,
        isDeliveryAvailable: true,
        weightKg: 0,
        stockQuantity: _parseInt(json['max_quantity']),
        ordersCount: 0,
        viewsCount: 0,
        specifications: null,
        createdAt: null,
        updatedAt: null,
      );
    }

    return CartItemModel(
      id: json['id']?.toString(),
      productId: json['product_id']?.toString(),
      product: product,
      quantity: _parseInt(json['quantity']),
      price: _parseDouble(json['price']),
      subtotal: _parseDouble(json['subtotal']),
      sellerId: json['seller_id']?.toString(),
      sellerName: json['seller_name']?.toString(),
      maxQuantity: _parseInt(json['max_quantity']) > 0
          ? _parseInt(json['max_quantity'])
          : null,
      unit: json['unit']?.toString(),
      productName: json['product_name']?.toString(),
      productImage: json['product_image']?.toString(),
    );
  }

  // ============================================================
  // FROM ORDER ITEM JSON (Checkout Response)
  // ============================================================
  factory CartItemModel.fromOrderItemJson(Map<String, dynamic> json) {
    String imageUrl = '';
    final imageField = json['product_image'];
    if (imageField != null) {
      if (imageField is String) {
        if (imageField.startsWith('[') && imageField.endsWith(']')) {
          try {
            final decoded = jsonDecode(imageField) as List?;
            if (decoded != null && decoded.isNotEmpty) {
              imageUrl = decoded.first.toString();
            }
          } catch (e) {
            imageUrl = imageField != '[' ? imageField : '';
          }
        } else {
          imageUrl = imageField;
        }
      } else if (imageField is List && imageField.isNotEmpty) {
        imageUrl = imageField.first.toString();
      }
    }

    if (imageUrl.isEmpty || imageUrl == '[') {
      imageUrl =
          'https://via.placeholder.com/400x400/1A8E5A/FFFFFF?text=No+Image';
    }
    imageUrl = ApiConstants.resolveAssetUrl(imageUrl);

    final product = ProductModel(
      id: json['product_id']?.toString() ?? '',
      name: json['product_name']?.toString() ?? 'Unknown Product',
      price: _parseDouble(json['price']),
      unit: json['unit']?.toString() ?? 'piece',
      category: '',
      description: '',
      imageUrl: imageUrl,
      images: imageUrl.isNotEmpty ? [imageUrl] : [],
      inStock: true,
      minQuantity: 1,
      maxQuantity: _parseInt(json['max_quantity']) > 0
          ? _parseInt(json['max_quantity'])
          : 100,
      rating: 0,
      reviewCount: 0,
      sku: '',
      sellerId: json['seller_id']?.toString() ?? '',
      sellerName: json['seller_name']?.toString() ?? '',
      deliveryFeePerKm: 0,
      preparationTimeMinutes: 0,
      isFeatured: false,
      isCodAvailable: true,
      isDeliveryAvailable: true,
      weightKg: 0,
      stockQuantity: _parseInt(json['max_quantity']),
      ordersCount: 0,
      viewsCount: 0,
      specifications: null,
      createdAt: null,
      updatedAt: null,
    );

    return CartItemModel(
      id: json['id']?.toString(),
      productId: json['product_id']?.toString(),
      product: product,
      quantity: _parseInt(json['quantity']),
      price: _parseDouble(json['price']),
      subtotal: _parseDouble(json['subtotal']),
      sellerId: json['seller_id']?.toString(),
      sellerName: json['seller_name']?.toString(),
      maxQuantity: _parseInt(json['max_quantity']) > 0
          ? _parseInt(json['max_quantity'])
          : null,
      unit: json['unit']?.toString(),
      productName: json['product_name']?.toString(),
      productImage: json['product_image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId ?? product.id,
      'quantity': quantity,
      'price': price,
    };
  }
}
