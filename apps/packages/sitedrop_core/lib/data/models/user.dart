// lib/data/models/user.dart
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/api_constants.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String email;

  @HiveField(4)
  final String role;

  @HiveField(5)
  final String? avatar;

  @HiveField(6)
  final bool isVerified;

  @HiveField(7)
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    required this.role,
    this.avatar,
    this.isVerified = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawAvatar = json['avatar']?.toString();
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'buyer',
      avatar: rawAvatar == null || rawAvatar.isEmpty
          ? rawAvatar
          : ApiConstants.resolveAssetUrl(rawAvatar),
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'avatar': avatar,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? avatar,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isBuyer => role == 'buyer';
  bool get isSeller => role == 'seller';
  bool get isDriver => role == 'driver';
  bool get isAdmin => role == 'admin';
  bool get isSuperAdmin => role == 'super-admin';
}
