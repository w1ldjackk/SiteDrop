import '../../core/utils/app_logger.dart';
// lib/data/models/order.dart

import '../../maps/app_map_point.dart';
import 'cart_item.dart';
import 'product.dart';
import 'tracking.dart';

enum OrderStatus {
  pending,
  confirmed,
  processing,
  readyForDelivery,
  inTransit,
  delivered,
  completed,
  cancelled,
  refunded,
  dispatched,
}

class OrderModel {
  final String id;
  final String orderNumber;
  final OrderStatus status;
  final double totalAmount;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double commissionAmount;
  final double sellerEarnings;
  final String deliveryAddress;
  final String deliveryPhone;
  final String paymentMethod;
  final String paymentStatus;
  final String notes;
  final DateTime createdAt;
  final DateTime? deliveryScheduledAt;
  final DateTime? deliveredAt;
  final DateTime? processedAt;
  final List<CartItemModel> items;
  final String currency;
  final Map<String, dynamic>? paymentData;
  final List<String> nextSteps;
  final String? specialInstructions;

  /// Destination pin (from `delivery_coordinates {lat, lng}` when the API
  /// exposes it — see Order::api_response). Null = map shows driver only.
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  /// `order.show → timeline` (or `GET /orders/{id}/timeline` refresh).
  final List<OrderTimelineEvent> timeline;

  /// Server flags (`can_cancel`, `can_review`) — fall back to local getters.
  final bool? serverCanCancel;
  final bool? serverCanReview;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.serviceFee = 0,
    this.commissionAmount = 0,
    this.sellerEarnings = 0,
    required this.deliveryAddress,
    required this.deliveryPhone,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.notes = '',
    required this.createdAt,
    this.deliveryScheduledAt,
    this.deliveredAt,
    this.processedAt,
    required this.items,
    this.currency = 'GHS',
    this.paymentData,
    this.nextSteps = const [],
    this.specialInstructions,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.timeline = const [],
    this.serverCanCancel,
    this.serverCanReview,
  });

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
  // FROM JSON - ✅ FIXED
  // ============================================================
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // ✅ Extract order data if nested
    Map<String, dynamic> orderData = json;
    if (json.containsKey('order') && json['order'] is Map<String, dynamic>) {
      orderData = json['order'] as Map<String, dynamic>;
    }

    // ✅ Debug logging
    AppLogger.d('📦 OrderData keys: ${orderData.keys}');
    AppLogger.d('📦 Has items: ${orderData.containsKey('items')}');
    if (orderData.containsKey('items')) {
      AppLogger.d('📦 Items type: ${orderData['items'].runtimeType}');
    }

    // ✅ Get items - handle multiple possible structures
    List<dynamic> rawItems = [];
    if (orderData.containsKey('items') && orderData['items'] is List) {
      rawItems = orderData['items'] as List<dynamic>;
    } else if (orderData.containsKey('order_items') &&
        orderData['order_items'] is List) {
      rawItems = orderData['order_items'] as List<dynamic>;
    } else if (orderData.containsKey('orderItems') &&
        orderData['orderItems'] is List) {
      rawItems = orderData['orderItems'] as List<dynamic>;
    }

    AppLogger.d('📦 Raw items count: ${rawItems.length}');

    // Get delivery phone
    String deliveryPhone = orderData['delivery_phone']?.toString() ?? '';
    if (deliveryPhone.isEmpty) {
      deliveryPhone = orderData['deliveryPhone']?.toString() ?? '';
    }

    // Get special instructions
    String specialInstructions =
        orderData['special_instructions']?.toString() ?? '';
    if (specialInstructions.isEmpty) {
      specialInstructions = orderData['notes']?.toString() ?? '';
    }

    // ✅ Parse items
    final parsedItems = rawItems.whereType<Map<String, dynamic>>().map((item) {
      // Check if item has a nested 'product' object
      if (item.containsKey('product') &&
          item['product'] is Map<String, dynamic>) {
        final productData = item['product'] as Map<String, dynamic>;
        final product = ProductModel.fromJson(productData);
        final quantity = _parseInt(item['quantity']);
        final price = _parseDouble(item['price'] ?? productData['price']);
        final subtotal = _parseDouble(item['subtotal'] ?? price * quantity);

        return CartItemModel(
          id: item['id']?.toString(),
          productId: product.id,
          product: product,
          quantity: quantity,
          price: price,
          subtotal: subtotal,
          sellerId: item['seller_id']?.toString(),
          sellerName: item['seller_name']?.toString(),
          maxQuantity: _parseInt(item['max_quantity']) > 0
              ? _parseInt(item['max_quantity'])
              : null,
          unit: item['unit']?.toString() ?? product.unit,
          productName: product.name,
          productImage: product.imageUrl,
        );
      } else {
        // Use the fromOrderItemJson factory
        return CartItemModel.fromOrderItemJson(item);
      }
    }).toList();

    AppLogger.d('📦 Parsed items count: ${parsedItems.length}');

    return OrderModel(
      id: orderData['id']?.toString() ?? '',
      orderNumber: orderData['order_number']?.toString() ?? 'SD-0000',
      status: _statusFromString(orderData['status']?.toString()),
      totalAmount: _parseDouble(orderData['total_amount']),
      subtotal: _parseDouble(orderData['subtotal']),
      deliveryFee: _parseDouble(orderData['delivery_fee']),
      serviceFee: _parseDouble(orderData['service_fee']),
      commissionAmount: _parseDouble(orderData['commission_amount']),
      sellerEarnings: _parseDouble(orderData['seller_earnings']),
      deliveryAddress: orderData['delivery_address']?.toString() ?? '',
      deliveryPhone: deliveryPhone,
      paymentMethod: orderData['payment_method']?.toString() ?? 'Mobile Money',
      paymentStatus: orderData['payment_status']?.toString() ?? 'pending',
      notes: orderData['notes']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(orderData['created_at']?.toString() ?? '') ??
          DateTime.now(),
      deliveryScheduledAt: DateTime.tryParse(
        orderData['delivery_scheduled_at']?.toString() ?? '',
      ),
      deliveredAt: DateTime.tryParse(
        orderData['delivered_at']?.toString() ?? '',
      ),
      processedAt: DateTime.tryParse(
        orderData['processed_at']?.toString() ?? '',
      ),
      currency: orderData['currency']?.toString() ?? 'GHS',
      items: parsedItems,
      specialInstructions: specialInstructions,
      deliveryLatitude: _parseCoord(orderData, 'lat', 'latitude'),
      deliveryLongitude: _parseCoord(orderData, 'lng', 'longitude', 'lon'),
      timeline: _parseTimeline(orderData['timeline']),
      serverCanCancel: _parseBoolOrNull(
        orderData['can_cancel'] ?? orderData['canCancel'],
      ),
      serverCanReview: _parseBoolOrNull(
        orderData['can_review'] ?? orderData['canReview'],
      ),
    );
  }

  /// `GET /orders/{id}` detail shape: `{order, timeline, can_cancel, …}`.
  /// Combines siblings into one [OrderModel] for the live tracker.
  factory OrderModel.fromDetailJson(Map<String, dynamic> json) {
    final orderData = json['order'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['order'] as Map)
        : Map<String, dynamic>.from(json);
    // Siblings live next to `order` in the detail payload.
    orderData['timeline'] ??= json['timeline'];
    orderData['can_cancel'] ??= json['can_cancel'];
    orderData['can_review'] ??= json['can_review'];
    return OrderModel.fromJson(orderData);
  }

  static double? _parseCoord(
    Map<String, dynamic> data,
    String shortKey,
    String longKey, [
    String altKey = '',
  ]) {
    // {delivery_coordinates: {lat, lng}} (preferred) or flat keys.
    final coords = data['delivery_coordinates'];
    if (coords is Map) {
      final v = coords[shortKey] ?? coords[longKey] ??
          (altKey.isNotEmpty ? coords[altKey] : null);
      final d = _parseDouble(v);
      if (v != null && (d != 0 || v.toString() == '0')) return d;
    }
    for (final k in [
      'delivery_$longKey',
      'delivery_$shortKey',
      longKey,
      shortKey,
      if (altKey.isNotEmpty) altKey,
    ]) {
      final v = data[k];
      if (v == null) continue;
      final d = double.tryParse(v.toString());
      if (d != null && d != 0) return d;
    }
    return null;
  }

  static List<OrderTimelineEvent> _parseTimeline(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => OrderTimelineEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static bool? _parseBoolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase().trim();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return null;
  }

  // ============================================================
  // FROM CHECKOUT JSON
  // ============================================================
  factory OrderModel.fromCheckoutJson(Map<String, dynamic> json) {
    final orderData = json['order'] as Map<String, dynamic>? ?? json;
    final itemsData = orderData['items'] as List<dynamic>? ?? [];
    final paymentData = json['payment'] as Map<String, dynamic>?;
    final nextSteps =
        (json['next_steps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    String specialInstructions =
        orderData['special_instructions']?.toString() ?? '';
    if (specialInstructions.isEmpty) {
      specialInstructions = orderData['notes']?.toString() ?? '';
    }

    return OrderModel(
      id: orderData['id']?.toString() ?? '',
      orderNumber: orderData['order_number']?.toString() ?? 'SD-0000',
      status: _statusFromString(orderData['status']?.toString()),
      totalAmount: _parseDouble(orderData['total_amount']),
      subtotal: _parseDouble(orderData['subtotal']),
      deliveryFee: _parseDouble(orderData['delivery_fee']),
      serviceFee: _parseDouble(orderData['service_fee']),
      commissionAmount: _parseDouble(orderData['commission_amount']),
      sellerEarnings: _parseDouble(orderData['seller_earnings']),
      deliveryAddress: orderData['delivery_address']?.toString() ?? '',
      deliveryPhone: orderData['delivery_phone']?.toString() ?? '',
      paymentMethod: orderData['payment_method']?.toString() ?? 'Mobile Money',
      paymentStatus: orderData['payment_status']?.toString() ?? 'pending',
      notes: orderData['notes']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(orderData['created_at']?.toString() ?? '') ??
          DateTime.now(),
      deliveryScheduledAt: DateTime.tryParse(
        orderData['delivery_scheduled_at']?.toString() ?? '',
      ),
      deliveredAt: DateTime.tryParse(
        orderData['delivered_at']?.toString() ?? '',
      ),
      processedAt: DateTime.tryParse(
        orderData['processed_at']?.toString() ?? '',
      ),
      currency: orderData['currency']?.toString() ?? 'GHS',
      items: itemsData
          .whereType<Map<String, dynamic>>()
          .map((item) => CartItemModel.fromOrderItemJson(item))
          .toList(),
      paymentData: paymentData,
      nextSteps: nextSteps,
      specialInstructions: specialInstructions,
    );
  }

  static OrderStatus _statusFromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'ready_for_delivery':
        return OrderStatus.readyForDelivery;
      case 'in_transit':
        return OrderStatus.inTransit;
      case 'delivered':
        return OrderStatus.delivered;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'dispatched':
        return OrderStatus.dispatched;
      default:
        return OrderStatus.pending;
    }
  }

  // ============================================================
  // GETTERS / ACCESSORS
  // ============================================================
  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.readyForDelivery:
        return 'Ready for Delivery';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.dispatched:
        return 'Dispatched';
    }
  }

  String get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return 'warning';
      case OrderStatus.confirmed:
        return 'info';
      case OrderStatus.processing:
        return 'info';
      case OrderStatus.readyForDelivery:
        return 'primary';
      case OrderStatus.inTransit:
        return 'primary';
      case OrderStatus.delivered:
        return 'success';
      case OrderStatus.completed:
        return 'success';
      case OrderStatus.cancelled:
        return 'danger';
      case OrderStatus.refunded:
        return 'secondary';
      case OrderStatus.dispatched:
        return 'primary';
    }
  }

  bool get canCancel {
    return status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.processing;
  }

  bool get isCompleted {
    return status == OrderStatus.completed || status == OrderStatus.delivered;
  }

  bool get isCancelled {
    return status == OrderStatus.cancelled || status == OrderStatus.refunded;
  }

  bool get requiresPayment {
    return paymentData != null && paymentData?['type'] == 'external';
  }

  bool get isPaid {
    return paymentStatus == 'paid';
  }

  String get code => orderNumber;

  DateTime? get eta => deliveryScheduledAt;

  // ============================================================
  // LIVE TRACKER
  // ============================================================
  /// Destination pin for the OSM tracker map (null when unknown).
  AppMapPoint? get destinationPoint {
    if (deliveryLatitude != null && deliveryLongitude != null) {
      return AppMapPoint(deliveryLatitude!, deliveryLongitude!);
    }
    return null;
  }

  /// Server `can_cancel` wins when present; else local status rule.
  bool get effectiveCanCancel => serverCanCancel ?? canCancel;

  bool get effectiveCanReview => serverCanReview ?? false;

  /// Active (still moving) vs terminal — controls auto-refresh polling.
  bool get isTrackingActive {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.processing:
      case OrderStatus.readyForDelivery:
      case OrderStatus.dispatched:
      case OrderStatus.inTransit:
        return true;
      case OrderStatus.delivered:
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return false;
    }
  }

  OrderModel copyWith({
    List<OrderTimelineEvent>? timeline,
    double? deliveryLatitude,
    double? deliveryLongitude,
    bool? serverCanCancel,
    bool? serverCanReview,
    OrderStatus? status,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      status: status ?? this.status,
      totalAmount: totalAmount,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      serviceFee: serviceFee,
      commissionAmount: commissionAmount,
      sellerEarnings: sellerEarnings,
      deliveryAddress: deliveryAddress,
      deliveryPhone: deliveryPhone,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      notes: notes,
      createdAt: createdAt,
      deliveryScheduledAt: deliveryScheduledAt,
      deliveredAt: deliveredAt,
      processedAt: processedAt,
      items: items,
      currency: currency,
      paymentData: paymentData,
      nextSteps: nextSteps,
      specialInstructions: specialInstructions,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      timeline: timeline ?? this.timeline,
      serverCanCancel: serverCanCancel ?? this.serverCanCancel,
      serverCanReview: serverCanReview ?? this.serverCanReview,
    );
  }
}
