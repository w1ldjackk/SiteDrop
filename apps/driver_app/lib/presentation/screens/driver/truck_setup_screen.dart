// lib/presentation/screens/driver/truck_setup_screen.dart
// Driver onboarding step 2: register truck so TruckMatcher can match trips.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/truck.dart';
import 'package:sitedrop_core/data/services/truck_service.dart';
import '../../providers/truck_provider.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import '../../widgets/common/app_back_button.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_dropdown.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_text_field.dart';

const _vehicleTypes = [
  'tipper',
  'flatbed',
  'tanker',
  'dump_truck',
  'concrete_mixer',
  'carrier',
  'other',
];

const _fuelTypes = ['diesel', 'petrol', 'electric', 'hybrid'];

// Driver-editable statuses (in_transit is system-managed during trips).
const _editStatuses = ['available', 'maintenance', 'inactive'];

class TruckSetupScreen extends ConsumerStatefulWidget {
  /// When set, the form edits this truck instead of registering a new one.
  final TruckModel? truck;

  const TruckSetupScreen({super.key, this.truck});

  @override
  ConsumerState<TruckSetupScreen> createState() => _TruckSetupScreenState();
}

class _TruckSetupScreenState extends ConsumerState<TruckSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reg = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _capacity = TextEditingController();
  final _mileage = TextEditingController();
  final _insurance = TextEditingController();

  String _vehicleType = 'tipper';
  String _fuelType = 'diesel';
  String _status = 'available';
  bool _saving = false;

  bool get _isEdit => widget.truck != null;

  @override
  void initState() {
    super.initState();
    final t = widget.truck;
    if (t != null) {
      _reg.text = t.registrationNumber;
      _make.text = t.make;
      _model.text = t.model;
      _year.text = t.year > 0 ? '${t.year}' : '';
      _capacity.text = t.capacityTons > 0 ? '${t.capacityTons}' : '';
      _mileage.text = t.currentMileage != null && t.currentMileage! > 0
          ? '${t.currentMileage}'
          : '';
      if (t.insuranceExpiry != null) {
        final d = t.insuranceExpiry!;
        _insurance.text =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      if (_vehicleTypes.contains(t.vehicleType)) {
        _vehicleType = t.vehicleType;
      }
      if (t.fuelType != null && _fuelTypes.contains(t.fuelType)) {
        _fuelType = t.fuelType!;
      }
      if (_editStatuses.contains(t.status)) {
        _status = t.status;
      }
    }
  }

  @override
  void dispose() {
    _reg.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _capacity.dispose();
    _mileage.dispose();
    _insurance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'registration_number': _reg.text.trim(),
        'make': _make.text.trim(),
        'model': _model.text.trim(),
        'year': int.tryParse(_year.text.trim()) ?? 0,
        'capacity_tons': double.tryParse(_capacity.text.trim()) ?? 0,
        'vehicle_type': _vehicleType,
        'fuel_type': _fuelType,
        if (_mileage.text.trim().isNotEmpty)
          'current_mileage': double.tryParse(_mileage.text.trim()) ?? 0,
        if (_insurance.text.trim().isNotEmpty)
          'insurance_expiry': _insurance.text.trim(),
        // Matcher-relevant: only the driver can flag maintenance/inactive.
        if (_isEdit) 'status': _status,
      };
      if (_isEdit) {
        final (ok, message) = await TruckService.updateTruck(
          widget.truck!.id,
          payload,
        );
        if (!mounted) return;
        if (ok) {
          ref.invalidate(myTrucksProvider);
          Helpers.showSuccessToast(message);
          context.pop();
        } else {
          Helpers.showErrorToast(message);
        }
        return;
      }
      final (ok, message, _) = await TruckService.createTruck(payload);
      if (!mounted) return;
      if (ok) {
        ref.invalidate(myTrucksProvider);
        Helpers.showSuccessToast(message);
        context.go(RouteNames.driverDashboard);
      } else {
        Helpers.showErrorToast(message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickInsuranceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      _insurance.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(
          context,
          _isEdit ? 'Edit truck' : 'Add your truck',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEdit) ...[
                  Text(
                    'Step 2 of 2 — your truck',
                    style: TextStyle(
                      color: context.palette.iconMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  _isEdit
                      ? 'Capacity, type, status and insurance decide which trips you get matched to.'
                      : 'Trips are matched by capacity, type, verification and insurance. Add your truck to start receiving requests.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _reg,
                  label: 'Registration number',
                  hint: 'e.g. GR 1234-24',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _make,
                        label: 'Make',
                        hint: 'e.g. MAN',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _model,
                        label: 'Model',
                        hint: 'e.g. TGS',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _year,
                        label: 'Year',
                        hint: 'e.g. 2020',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final y = int.tryParse((v ?? '').trim());
                          if (y == null || y < 1990 || y > DateTime.now().year) {
                            return 'Enter a valid year';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _capacity,
                        label: 'Capacity (tons)',
                        hint: 'e.g. 20',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final c = double.tryParse((v ?? '').trim());
                          if (c == null || c <= 0) return 'Enter tons';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomDropdown<String>(
                  label: 'Vehicle type',
                  value: _vehicleType,
                  items: _vehicleTypes
                      .map(
                        (t) => {
                          'value': t,
                          'label': t.replaceAll('_', ' '),
                        },
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _vehicleType = v ?? 'tipper'),
                ),
                const SizedBox(height: 12),
                CustomDropdown<String>(
                  label: 'Fuel type',
                  value: _fuelType,
                  items: _fuelTypes
                      .map((t) => {'value': t, 'label': t})
                      .toList(),
                  onChanged: (v) => setState(() => _fuelType = v ?? 'diesel'),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _mileage,
                  label: 'Current mileage (km, optional)',
                  hint: 'e.g. 120000',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _insurance,
                  label: 'Insurance expiry (YYYY-MM-DD)',
                  hint: 'Required for matching',
                  readOnly: true,
                  onTap: _pickInsuranceDate,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Insurance date is required for matching'
                      : null,
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 12),
                  CustomDropdown<String>(
                    label: 'Status (matching)',
                    value: _status,
                    items: _editStatuses
                        .map(
                          (s) => {
                            'value': s,
                            'label': s.replaceAll('_', ' '),
                          },
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _status = v ?? 'available'),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: _save,
                  isLoading: _saving,
                  text: _isEdit ? 'Save changes' : 'Save truck & go online',
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(RouteNames.driverDashboard),
                    child: const Text('Skip for now'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
