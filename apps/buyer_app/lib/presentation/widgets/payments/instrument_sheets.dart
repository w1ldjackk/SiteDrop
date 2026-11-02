// lib/presentation/widgets/payments/instrument_sheets.dart
// Add / edit saved instruments: MoMo (network + phone), card (number +
// expiry + holder), bank (bank + account + holder). Validation mirrors
// the server; server errors surface via toast.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/validators.dart';
import 'package:sitedrop_core/data/models/payment_instrument.dart';
import 'package:sitedrop_core/data/services/instrument_service.dart';
import '../../providers/instruments_provider.dart';

const momoNetworks = ['MTN', 'Vodafone', 'AirtelTigo'];

/// Step 1: pick the instrument type.
Future<void> showAddInstrumentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _TypeOption(
              icon: Icons.phone_android,
              title: 'Mobile Money',
              subtitle: 'MTN, Vodafone or AirtelTigo number',
              onTap: () {
                Navigator.pop(ctx);
                showInstrumentFormSheet(context, 'mobile_money');
              },
            ),
            _TypeOption(
              icon: Icons.credit_card,
              title: 'Card',
              subtitle: 'Visa, Mastercard or Amex',
              onTap: () {
                Navigator.pop(ctx);
                showInstrumentFormSheet(context, 'card');
              },
            ),
            _TypeOption(
              icon: Icons.account_balance_outlined,
              title: 'Bank account',
              subtitle: 'Direct bank transfer details',
              onTap: () {
                Navigator.pop(ctx);
                showInstrumentFormSheet(context, 'bank');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.palette.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: context.palette.textMuted),
      ),
      trailing:
          Icon(Icons.chevron_right, color: context.palette.iconMuted),
      onTap: onTap,
    );
  }
}

// ============================================================
// ADD / EDIT FORM
// ============================================================

/// Step 2: per-type form. Pass [existing] to edit (number fields optional).
Future<void> showInstrumentFormSheet(
  BuildContext context,
  String type, {
  PaymentInstrumentModel? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InstrumentForm(type: type, existing: existing),
  );
}

class _InstrumentForm extends ConsumerStatefulWidget {
  final String type;
  final PaymentInstrumentModel? existing;

  const _InstrumentForm({required this.type, this.existing});

  @override
  ConsumerState<_InstrumentForm> createState() => _InstrumentFormState();
}

class _InstrumentFormState extends ConsumerState<_InstrumentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _phone;
  late final TextEditingController _number;
  late final TextEditingController _exp;
  late final TextEditingController _holder;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  String _network = momoNetworks.first;
  bool _saving = false;

  bool get isEdit => widget.existing != null;
  bool get isMomo => widget.type == 'mobile_money';
  bool get isCard => widget.type == 'card';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _number = TextEditingController();
    _exp = TextEditingController(text: e?.exp ?? '');
    _holder = TextEditingController(text: e?.holder ?? '');
    _bank = TextEditingController(text: e?.network ?? '');
    _account = TextEditingController();
    if (e?.network != null && momoNetworks.contains(e!.network)) {
      _network = e.network!;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _phone.dispose();
    _number.dispose();
    _exp.dispose();
    _holder.dispose();
    _bank.dispose();
    _account.dispose();
    super.dispose();
  }

  String get _title {
    final base = isEdit ? 'Edit' : 'Add';
    if (isMomo) return '$base Mobile Money';
    if (isCard) return '$base card';
    return '$base bank account';
  }

  Map<String, dynamic>? _collect() {
    final body = <String, dynamic>{
      if (_label.text.trim().isNotEmpty) 'label': _label.text.trim(),
    };
    if (isMomo) {
      final phone = _phone.text.trim().replaceAll(RegExp(r'\s+'), '');
      if (phone.isEmpty && isEdit) return body;
      final err = Validators.phone(phone);
      if (err != null) {
        Helpers.showErrorToast(err);
        return null;
      }
      body['network'] = _network;
      body['phone'] = phone;
      return body;
    }
    if (isCard) {
      final number = _number.text.replaceAll(RegExp(r'\s+'), '');
      if (number.isEmpty && isEdit) {
        if (_exp.text.trim().isNotEmpty &&
            !InstrumentService.expValid(_exp.text)) {
          Helpers.showErrorToast('Expiry must be in the future (MM/YY)');
          return null;
        }
        if (_exp.text.trim().isNotEmpty) body['exp'] = _exp.text.trim();
        if (_holder.text.trim().isNotEmpty) {
          body['holder'] = _holder.text.trim();
        }
        return body;
      }
      if (!InstrumentService.luhnValid(number)) {
        Helpers.showErrorToast('Card number looks invalid');
        return null;
      }
      if (!InstrumentService.expValid(_exp.text)) {
        Helpers.showErrorToast('Expiry must be in the future (MM/YY)');
        return null;
      }
      if (_holder.text.trim().isEmpty) {
        Helpers.showErrorToast('Card holder name is required');
        return null;
      }
      body['number'] = number;
      body['exp'] = _exp.text.trim();
      body['holder'] = _holder.text.trim();
      return body;
    }
    // Bank.
    final account = _account.text.replaceAll(RegExp(r'\s+'), '');
    if (account.isEmpty && isEdit) {
      if (_bank.text.trim().isNotEmpty) {
        body['bank_name'] = _bank.text.trim();
      }
      if (_holder.text.trim().isNotEmpty) {
        body['holder'] = _holder.text.trim();
      }
      return body;
    }
    if (_bank.text.trim().isEmpty) {
      Helpers.showErrorToast('Bank name is required');
      return null;
    }
    if (!RegExp(r'^\d{8,20}$').hasMatch(account)) {
      Helpers.showErrorToast('Account number must be 8–20 digits');
      return null;
    }
    if (_holder.text.trim().isEmpty) {
      Helpers.showErrorToast('Account holder name is required');
      return null;
    }
    body['bank_name'] = _bank.text.trim();
    body['account_number'] = account;
    body['holder'] = _holder.text.trim();
    return body;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final body = _collect();
    if (body == null) return;
    setState(() => _saving = true);
    try {
      final (ok, message) = isEdit
          ? await InstrumentService.update(widget.existing!.id, body)
          : await InstrumentService.add({'type': widget.type, ...body});
      if (!mounted) return;
      if (ok) {
        ref.invalidate(instrumentsProvider);
        ref.invalidate(defaultInstrumentProvider);
        Navigator.pop(context);
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isMomo) ...[
                    _networkDropdown(context),
                    const SizedBox(height: 12),
                    _field(
                      context,
                      controller: _phone,
                      label: 'Phone number',
                      hint: (widget.existing?.phone?.isNotEmpty == true)
                          ? 'Current: ${widget.existing!.phone}'
                          : '024 123 4567',
                      keyboard: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s]'),
                        ),
                      ],
                    ),
                  ],
                  if (isCard) ...[
                    _field(
                      context,
                      controller: _number,
                      label:
                          'Card number${isEdit ? ' (leave blank to keep)' : ''}',
                      hint: isEdit
                          ? '•••• •••• •••• ${widget.existing?.last4 ?? ''}'
                          : '1234 5678 9012 3456',
                      keyboard: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _CardNumberFormatter(),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_number.text
                        .replaceAll(' ', '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Detected: ${InstrumentService.cardBrand(_number.text)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            context,
                            controller: _exp,
                            label: 'Expiry',
                            hint: 'MM/YY',
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _ExpiryFormatter(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _field(
                            context,
                            controller: _holder,
                            label: 'Holder name',
                            hint: 'AMA SERWAA',
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isMomo && !isCard) ...[
                    _field(
                      context,
                      controller: _bank,
                      label: 'Bank name',
                      hint: 'GCB, Ecobank, Stanbic…',
                    ),
                    const SizedBox(height: 12),
                    _field(
                      context,
                      controller: _account,
                      label:
                          'Account number${isEdit ? ' (leave blank to keep)' : ''}',
                      hint: isEdit
                          ? '••••••${widget.existing?.last4 ?? ''}'
                          : '10–20 digits',
                      keyboard: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      context,
                      controller: _holder,
                      label: 'Account holder name',
                      hint: 'AMA SERWAA',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _field(
                    context,
                    controller: _label,
                    label: 'Nickname (optional)',
                    hint: 'e.g. My MTN',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEdit ? 'Save changes' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _networkDropdown(BuildContext context) {
    final p = context.palette;
    return DropdownButtonFormField<String>(
      initialValue: _network,
      style: TextStyle(color: p.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Network',
        filled: true,
        fillColor: p.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.borderStrong),
        ),
      ),
      items: [
        for (final n in momoNetworks)
          DropdownMenuItem(value: n, child: Text(n)),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _network = v);
      },
    );
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    final p = context.palette;
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(color: p.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: p.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.borderStrong),
        ),
      ),
    );
  }
}

/// Groups card digits in 4s while typing.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) digits = digits.substring(0, 16);
    final grouped = [
      for (var i = 0; i < digits.length; i += 4)
        digits.substring(
          i,
          (i + 4).clamp(0, digits.length),
        ),
    ].join(' ');
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}

/// Turns 1229 into 12/29 while typing.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
