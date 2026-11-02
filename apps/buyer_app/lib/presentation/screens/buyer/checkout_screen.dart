// lib/presentation/screens/buyer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/app_constants.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/address.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/payment.dart';
import 'package:sitedrop_core/sitedrop_core.dart'
    show PaymentInstrumentModel;
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/instruments_provider.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_text_field.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_dropdown.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _momoPhoneController = TextEditingController();
  String _paymentMethod = AppConstants.paymentMethods.first;
  bool _isLoading = false;
  String _tempPaymentMethod = '';
  AddressModel? _selectedAddress;
  /// MoMo payer wallet entered manually (only shown when no saved wallet
  /// exists). Sent as `phone_number`.
  String? _momoNetwork;
  /// Id of the address last chosen by auto-sync (default/first).
  /// `null` means the user picked an address manually — do not override it
  /// when the book refreshes (unless that address was deleted).
  String? _lastAutoSelectedId;

  late AnimationController _bottomSheetAnimationController;

  /// Return to buyer shell cart tab (keeps bottom nav). Never use /cart alone.
  void _goBackToCartShell() {
    ref.read(mainTabIndexProvider.notifier).setIndex(2);
    context.go(RouteNames.home);
  }

  @override
  void initState() {
    super.initState();
    _bottomSheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Pre-select the saved default: default instrument's method first,
    // then the method-level default (Account → Payment Methods).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(defaultInstrumentProvider.future).then((instrument) {
        if (!mounted) return;
        final method = instrument?.methodType.displayName;
        if (method != null &&
            AppConstants.paymentMethods.contains(method) &&
            method != _paymentMethod) {
          setState(() => _paymentMethod = method);
          return;
        }
        ref.read(defaultPaymentMethodProvider.future).then((fallback) {
          if (!mounted) return;
          if (AppConstants.paymentMethods.contains(fallback) &&
              fallback != _paymentMethod) {
            setState(() => _paymentMethod = fallback);
          }
        }).catchError((_) {});
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _momoPhoneController.dispose();
    _bottomSheetAnimationController.dispose();
    super.dispose();
  }

  bool get _isMoMoSelected =>
      (AppConstants.paymentMethodApiMap[_paymentMethod] ?? _paymentMethod) ==
      'mobile_money';

  /// Saved default MoMo instrument (phone + network already added under
  /// Payment Methods). Shown as a card like the delivery address — never
  /// prefilled into editable fields.
  PaymentInstrumentModel? _savedMomo(PaymentInstrumentModel? instrument) {
    if (instrument != null &&
        instrument.type == 'mobile_money' &&
        (instrument.phone?.trim().isNotEmpty == true)) {
      return instrument;
    }
    return null;
  }

  String _momoNetworkFor(
    PaymentInstrumentModel? instrument,
    String phone,
  ) {
    final raw = instrument != null && instrument.type == 'mobile_money'
        ? (instrument.network?.trim() ?? '')
        : '';
    final mapped = AppConstants.mobileMoneyNetworkApiMap[raw] ??
        AppConstants.mobileMoneyNetworkApiMap[raw.toUpperCase()];
    if (mapped != null) return mapped;
    return AppConstants.networkForPhone(phone) ?? 'MTN';
  }

  void _syncSelectedAddress(AddressBook book) {
    if (book.addresses.isEmpty) {
      if (_selectedAddress != null || _lastAutoSelectedId != null) {
        setState(() {
          _selectedAddress = null;
          _lastAutoSelectedId = null;
        });
      }
      return;
    }

    final preferred = book.defaultAddress ?? book.addresses.first;
    final wasAutoSelected = _selectedAddress != null &&
        _lastAutoSelectedId != null &&
        _selectedAddress!.id == _lastAutoSelectedId;

    // Current selection still in book?
    if (_selectedAddress != null) {
      final match =
          book.addresses.where((a) => a.id == _selectedAddress!.id).toList();
      if (match.isNotEmpty) {
        final fresh = match.first;

        // Still in auto mode: follow a newly changed default.
        if (wasAutoSelected && preferred.id != fresh.id) {
          setState(() {
            _selectedAddress = preferred;
            _lastAutoSelectedId = preferred.id;
          });
          return;
        }

        // Manual or same auto pick — only refresh fields if data changed.
        final contentChanged = fresh.fullAddress != _selectedAddress!.fullAddress ||
            fresh.phone != _selectedAddress!.phone ||
            fresh.isDefault != _selectedAddress!.isDefault ||
            fresh.displayLabel != _selectedAddress!.displayLabel ||
            fresh.receiverName != _selectedAddress!.receiverName;
        if (contentChanged) {
          setState(() {
            _selectedAddress = fresh;
            // Keep auto marker only if this was still the auto selection.
            if (wasAutoSelected) {
              _lastAutoSelectedId = fresh.id;
            }
          });
        }
        return;
      }
    }

    // No selection, or previous address was deleted → auto-pick.
    if (_selectedAddress?.id != preferred.id ||
        _lastAutoSelectedId != preferred.id) {
      setState(() {
        _selectedAddress = preferred;
        _lastAutoSelectedId = preferred.id;
      });
    }
  }

  void _selectAddressManually(AddressModel address) {
    setState(() {
      _selectedAddress = address;
      // Clear auto marker so refresh won't steal the user's choice.
      _lastAutoSelectedId = null;
    });
  }

  Future<void> _openAddAddress() async {
    await context.push(RouteNames.addAddress);
    if (!mounted) return;
    ref.invalidate(addressBookProvider);
  }

  Future<void> _openManageAddresses() async {
    await context.push(RouteNames.addresses);
    if (!mounted) return;
    ref.invalidate(addressBookProvider);
  }

  // ============================================================
  // FEE CALCULATIONS
  // ============================================================
  double _calculateDeliveryFee(List cartItems) {
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    return subtotal >= 500 ? 0 : 20.0;
  }

  double _calculateServiceFee(double subtotal) {
    return subtotal * 0.10;
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      Helpers.showErrorToast('Please select a delivery address');
      return;
    }

    final address = _selectedAddress!;
    final phone = address.phone?.trim() ?? '';
    if (phone.isEmpty) {
      Helpers.showErrorToast(
        'Selected address has no phone. Edit it or choose another.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Mobile Money needs the payer wallet + network (CheckoutRequest).
    // Saved wallet (Payment Methods) wins; manual entry only as fallback.
    String? momoPhone;
    String? momoNetwork;
    if (_isMoMoSelected) {
      PaymentInstrumentModel? instrument;
      try {
        instrument = await ref.read(defaultMomoInstrumentProvider.future);
      } catch (_) {}
      final saved = _savedMomo(instrument);
      final typed = _momoPhoneController.text.trim();
      if (typed.isNotEmpty) {
        momoPhone = typed;
        momoNetwork = _momoNetwork ?? _momoNetworkFor(instrument, typed);
      } else if (saved != null) {
        momoPhone = saved.phone!.trim();
        momoNetwork = _momoNetworkFor(instrument, momoPhone);
      }
      if (momoPhone == null || momoPhone.isEmpty) {
        Helpers.showErrorToast(
          'Add a mobile money wallet in Payment Methods first',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final cartItems = ref.read(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    // Prefer saved coordinates; fall back to Accra CBD.
    final latitude = address.latitude ?? 5.6037;
    final longitude = address.longitude ?? -0.1870;

    try {
      final result = await ref
          .read(ordersProvider.notifier)
          .placeOrder(
            items: cartItems,
            deliveryAddress: address.fullAddress,
            deliveryPhone: phone,
            paymentMethod: _paymentMethod,
            phoneNumber: momoPhone,
            network: momoNetwork,
            notes: [
              if (_notesController.text.trim().isNotEmpty)
                _notesController.text.trim(),
              if (address.deliveryInstructions != null &&
                  address.deliveryInstructions!.trim().isNotEmpty)
                'Delivery note: ${address.deliveryInstructions!.trim()}',
              if (address.receiverName != null &&
                  address.receiverName!.trim().isNotEmpty)
                'Receiver: ${address.receiverName!.trim()}',
            ].join('\n'),
            latitude: latitude,
            longitude: longitude,
          );

      // Clear cart after successful order
      cartNotifier.clearCart();

      if (mounted) {
        // Get the order from result
        final order = result['order'] as OrderModel;
        final paymentData = result['paymentData'] as Map<String, dynamic>?;

        if (paymentData != null && paymentData['type'] == 'external') {
          // Navigate to payment screen
          Helpers.showInfoToast(
            'Please complete payment to confirm your order',
          );
          context.go(
            RouteNames.payment,
            extra: {
              'orderId': order.id,
              'paymentUrl': paymentData['payment_url'],
              'amount': paymentData['amount'],
              'reference': paymentData['reference'],
              'paymentMethod': paymentData['method'],
            },
          );
        } else {
          // Order confirmed, go to tracking
          Helpers.showSuccessToast('Order placed successfully!');
          context.go(RouteNames.orderTracking.replaceAll(':orderId', order.id));
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // PAYMENT METHOD BOTTOM SHEET
  // ============================================================
  void _showPaymentMethodsSheet() {
    _tempPaymentMethod = _paymentMethod;

    // Cash on Delivery is only offered when every cart product allows it
    // (seller "Cash on Delivery" toggle). Otherwise hide it and fall back.
    final codAllowed =
        ref.read(cartProvider).every((i) => i.product.isCodAvailable);
    final methods = AppConstants.paymentMethods
        .where((m) => m != 'Cash on Delivery' || codAllowed)
        .toList();
    if (!methods.contains(_tempPaymentMethod)) {
      _tempPaymentMethod = methods.first;
    }

    _bottomSheetAnimationController.reset();
    _bottomSheetAnimationController.forward();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      transitionAnimationController: _bottomSheetAnimationController,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Material(
            color: Colors.transparent,
            child: Container(
              // Cap sheet height so short / landscape devices don't overflow.
              height: (MediaQuery.sizeOf(context).height *
                      (MediaQuery.sizeOf(context).height < 640 ? 0.9 : 0.78))
                  .clamp(320.0, MediaQuery.sizeOf(context).height * 0.92),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.palette.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Payment Method',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.palette.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            CupertinoIcons.clear,
                            color: context.palette.textMuted,
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: context.palette.divider, height: 1),
                  // Payment Methods List
                  if (!codAllowed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: context.palette.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cash on Delivery is unavailable for items in your cart.',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.palette.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: methods.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: context.palette.divider,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final method = methods[index];
                          final isSelected = _tempPaymentMethod == method;
                          final isMoMo =
                              (AppConstants.paymentMethodApiMap[method] ??
                                      method) ==
                                  'mobile_money';
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPaymentOption(
                                method: method,
                                isSelected: isSelected,
                                onTap: () {
                                  setSheetState(() {
                                    _tempPaymentMethod = method;
                                  });
                                },
                              ),
                              // Wallet number detail lives here, not on
                              // the checkout body. Reactive: shows a
                              // spinner while loading, saved wallet
                              // once loaded, manual entry if none.
                              if (isMoMo && isSelected)
                                Consumer(
                                  builder: (context, ref, _) {
                                    final momoAsync = ref.watch(
                                      defaultMomoInstrumentProvider,
                                    );
                                    return momoAsync.when(
                                      data: (instrument) =>
                                          _buildMomoSheetDetail(
                                        setSheetState,
                                        _savedMomo(instrument),
                                      ),
                                      loading: () => Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: context.palette.surfaceMuted,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      error: (_, _) =>
                                          _buildMomoSheetDetail(
                                        setSheetState,
                                        null,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  // Confirm Button at bottom
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      border: Border(
                        top: BorderSide(color: context.palette.divider, width: 1),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Selected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.palette.textMuted,
                                  ),
                                ),
                                Text(
                                  _tempPaymentMethod,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _paymentMethod = _tempPaymentMethod;
                                });
                                Navigator.pop(context);
                                Helpers.showSuccessToast(
                                  'Payment method updated to $_paymentMethod',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text('Confirm'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? context.palette.primarySoft : AppColors.grey100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getPaymentIcon(method),
          color: isSelected ? AppColors.primary : AppColors.grey600,
          size: 22,
        ),
      ),
      title: Text(
        method,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppColors.primary : AppColors.grey800,
        ),
      ),
      subtitle: Text(
        _getPaymentSubtitle(method),
        style: TextStyle(fontSize: 12, color: context.palette.textMuted),
      ),
      trailing: isSelected
          ? Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.white, size: 16),
            )
          : const SizedBox.shrink(),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: context.palette.primarySoft.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  /// MoMo wallet detail inside the method sheet: saved number display,
  /// or manual entry when no wallet is saved yet.
  Widget _buildMomoSheetDetail(
    StateSetter setSheetState,
    PaymentInstrumentModel? saved,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: saved != null
          ? Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saved.headline,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        'Prompt goes to this wallet',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RouteNames.paymentMethods);
                  },
                  child: const Text('Change'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No saved wallet — enter the number to charge',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _momoPhoneController,
                  label: 'MoMo number',
                  hint: 'e.g. 0241234567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                CustomDropdown<String>(
                  label: 'Network',
                  value: _momoNetwork ?? 'MTN',
                  items: const [
                    {'value': 'MTN', 'label': 'MTN Mobile Money'},
                    {'value': 'Vodafone', 'label': 'Vodafone Cash'},
                    {'value': 'AirtelTigo', 'label': 'AirtelTigo Money'},
                  ],
                  onChanged: (v) =>
                      setSheetState(() => _momoNetwork = v ?? 'MTN'),
                ),
              ],
            ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Mobile Money':
        return Icons.phone_android;
      case 'Paystack':
        return Icons.payment;
      case 'Cash on Delivery':
        return Icons.money;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Wallet Balance':
        return Icons.wallet;
      default:
        return Icons.payment_outlined;
    }
  }

  String _getPaymentSubtitle(String method) {
    switch (method) {
      case 'Mobile Money':
        return 'MTN, Vodafone, AirtelTigo';
      case 'Paystack':
        return 'Card, Bank, Mobile Money';
      case 'Cash on Delivery':
        return 'Pay when you receive';
      case 'Bank Transfer':
        return 'Direct bank transfer';
      case 'Wallet Balance':
        return 'Pay using your wallet balance';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    // Never keep COD selected when the cart contains a product whose seller
    // disabled it (e.g. restored default instrument).
    if (_paymentMethod == 'Cash on Delivery' &&
        cartItems.any((i) => !i.product.isCodAvailable)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _paymentMethod = 'Mobile Money');
      });
    }

    // Calculate totals
    final subtotal = cartNotifier.subtotal;
    final itemCount = cartNotifier.itemCount;
    final deliveryFee = _calculateDeliveryFee(cartItems);
    final serviceFee = _calculateServiceFee(subtotal);
    final total = subtotal + deliveryFee + serviceFee;

    if (cartItems.isEmpty) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBackToCartShell();
        },
        child: Scaffold(
          backgroundColor: context.palette.background,
          appBar: AppBar(
            backgroundColor: context.palette.surface,
            elevation: 0,
            title: appBarTitle(context, 'Checkout'),
            leading: AppBackButton(
              onPressed: _goBackToCartShell,
              fallbackRoute: RouteNames.home,
              fallbackTabIndex: 2,
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: context.palette.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 60,
                    color: context.palette.iconMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your cart is empty',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add items to proceed with checkout',
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    ref.read(mainTabIndexProvider.notifier).setIndex(0);
                    context.go(RouteNames.home);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Browse Products'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackToCartShell();
      },
      child: LoadingOverlay(
      isLoading: _isLoading,
      message: 'Placing order…',
      child: Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Checkout'),
        leading: AppBackButton(
          onPressed: _goBackToCartShell,
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 2,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              Card(
                elevation: 0,
                color: context.palette.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.palette.divider, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...cartItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity}x ${item.product.name}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.palette.icon,
                                  ),
                                ),
                              ),
                              Text(
                                Helpers.formatPrice(item.lineTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: context.palette.divider, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Subtotal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              Helpers.formatPrice(subtotal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Delivery Fee',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              deliveryFee > 0
                                  ? Helpers.formatPrice(deliveryFee)
                                  : 'Free',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: deliveryFee > 0
                                    ? AppColors.grey800
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Service Fee (10%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              Helpers.formatPrice(serviceFee),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(color: context.palette.divider, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: context.palette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              Helpers.formatPrice(total),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$itemCount ${itemCount > 1 ? 'items' : 'item'}',
                          style: TextStyle(
                            color: context.palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ============================================================
              // PAYMENT METHOD SECTION
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showPaymentMethodsSheet,
                    child: Row(
                      children: [
                        Text(
                          'Change',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.forward,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.palette.borderStrong, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.palette.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getPaymentIcon(_paymentMethod),
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _paymentMethod,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          Text(
                            _getPaymentSubtitle(_paymentMethod),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showPaymentMethodsSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Change',
                              style: TextStyle(
                                color: context.palette.icon,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 14,
                              color: context.palette.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ============================================================
              // DELIVERY ADDRESS (saved book)
              // ============================================================
              _buildDeliveryAddressSection(context),
              const SizedBox(height: 24),

              // ============================================================
              // ORDER NOTES
              // ============================================================
              Text(
                'Order Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _notesController,
                hint: 'Any special instructions (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Place Order Button
              PrimaryButton(
                onPressed: _selectedAddress == null ? null : _placeOrder,
                isLoading: _isLoading,
                text: 'Place Order',
                height: 56,
                fontSize: 18,
              ),

              const SizedBox(height: 16),

              // Security note
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: context.palette.iconMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment is secure and encrypted',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.palette.textMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  // ============================================================
  // DELIVERY ADDRESS UI
  // ============================================================
  Widget _buildDeliveryAddressSection(BuildContext context) {
    final bookAsync = ref.watch(addressBookProvider);
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Delivery Address',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: p.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openAddAddress,
              icon: Icon(Icons.add, size: 18, color: AppColors.primary),
              label: Text(
                'Add new',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        bookAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingWidget.compact(),
          ),
          error: (e, _) => _buildAddressError(context, e.toString()),
          data: (book) {
            // Schedule selection sync after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncSelectedAddress(book);
            });

            if (book.addresses.isEmpty) {
              return _buildNoAddressPrompt(context);
            }

            return Column(
              children: [
                ...book.addresses.map((address) {
                  final selected = _selectedAddress?.id == address.id;
                  return _buildAddressCard(context, address, selected);
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _openManageAddresses,
                    child: Text(
                      'Manage addresses',
                      style: TextStyle(
                        color: p.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNoAddressPrompt(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, size: 40, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            'No delivery address yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Add a saved address so we know where to deliver your order. You won’t need to type it again at checkout.',
            style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: _openAddAddress,
              text: 'Add delivery address',
              height: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressError(BuildContext context, String message) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Could not load addresses',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: p.textMuted),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => ref.invalidate(addressBookProvider),
            child: Text('Retry', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    AddressModel address,
    bool selected,
  ) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectAddressManually(address),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : p.border,
                width: selected ? 2 : 1,
              ),
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : p.surface,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : p.iconMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              address.displayLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (address.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: p.textMuted,
                          height: 1.35,
                        ),
                      ),
                      if (address.receiverName != null &&
                          address.receiverName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${address.receiverName}'
                          '${address.phone != null && address.phone!.isNotEmpty ? ' · ${address.phone}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: p.textSecondary,
                          ),
                        ),
                      ] else if (address.phone != null &&
                          address.phone!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          address.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
