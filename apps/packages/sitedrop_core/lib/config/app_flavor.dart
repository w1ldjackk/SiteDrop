/// Which role app is running.
/// Prefer `--dart-define=APP_ROLE=buyer|seller|driver` (see [AppConfig.role]).
enum AppFlavor {
  buyer,
  seller,
  driver;

  /// Fixed register/login role string sent to Laravel.
  String get apiRole => name;

  bool get isBuyer => this == AppFlavor.buyer;
  bool get isSeller => this == AppFlavor.seller;
  bool get isDriver => this == AppFlavor.driver;

  /// Parse APP_ROLE / flavor string (case-insensitive).
  static AppFlavor? fromString(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    return switch (v) {
      'buyer' || 'customer' || 'user' => AppFlavor.buyer,
      'seller' || 'vendor' => AppFlavor.seller,
      'driver' || 'rider' => AppFlavor.driver,
      _ => null,
    };
  }
}
