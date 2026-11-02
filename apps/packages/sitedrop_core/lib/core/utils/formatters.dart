// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    return formatter.format(amount);
  }

  static String formatCurrencyShort(double amount) {
    if (amount >= 1000000) {
      return 'GHS ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'GHS ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return formatCurrency(amount);
  }

  static String formatDate(DateTime date) {
    final formatter = DateFormat('dd MMM yyyy');
    return formatter.format(date);
  }

  static String formatDateTime(DateTime date) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    return formatter.format(date);
  }

  static String formatTime(DateTime date) {
    final formatter = DateFormat('hh:mm a');
    return formatter.format(date);
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return formatDate(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // FIXED: Removed the unused parameter
  static String formatPhoneNumber(String phone) {
    const String ghanaCountryCode = '+233';
    // Remove any non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Check if it's a Ghana number
    if (cleaned.startsWith('233')) {
      cleaned = cleaned.substring(3);
    }

    // Format as Ghana number
    if (cleaned.length == 9) {
      cleaned = '0$cleaned';
    }

    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '$ghanaCountryCode${cleaned.substring(1)}';
    }

    return phone;
  }

  static String formatPhoneDisplay(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    } else if (cleaned.startsWith('233') && cleaned.length == 12) {
      return '+${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6, 9)} ${cleaned.substring(9)}';
    }
    return phone;
  }

  static String formatOrderCode(String code) {
    if (code.isEmpty) return 'SD-0000';
    if (code.startsWith('SD-')) return code;
    return 'SD-$code';
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  static String titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map(capitalize).join(' ');
  }

  static String formatWeight(double weight, String unit) {
    final formatter = NumberFormat.decimalPattern();
    return '${formatter.format(weight)} $unit';
  }

  static String formatQuantity(int quantity) {
    final formatter = NumberFormat.decimalPattern();
    return formatter.format(quantity);
  }

  static String formatPercentage(double percentage) {
    final formatter = NumberFormat.decimalPattern();
    return '${formatter.format(percentage)}%';
  }
}
