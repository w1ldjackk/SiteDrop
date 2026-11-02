// lib/presentation/screens/profile/user/address_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
// OSM default (free, no API key). Google kept as commented legacy backup.
// LEGACY (Google backup — commented out for now):
// import 'package:flutter/foundation.dart';
// import 'package:flutter/gestures.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sitedrop_core/sitedrop_core.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/common/app_back_button.dart';
// OSM default (free, no API key):
import '../../../widgets/maps/app_osm_map.dart';
import '../../../widgets/maps/sitedrop_map_picker.dart';
// LEGACY (Google backup — commented out for now):
// import '../../../widgets/maps/app_google_map.dart';
// import '../../../widgets/maps/app_map.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  final String? addressId;

  const AddressFormScreen({super.key, this.addressId});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isDefault = false;
  bool _saving = false;
  bool _loading = false;
  bool _locating = false;
  AddressType _type = AddressType.home;

  /// Map pin — stored as addresses.coordinates { lat, lng } on the API.
  /// OSM-first (AppMapPoint, no API key). Google LatLng kept as legacy below.
  double? _latitude;
  double? _longitude;
  AppMapController? _mapController;
  // LEGACY (Google backup — commented out for now):
  // GoogleMapController? _mapControllerLegacy;

  /// Default camera: Accra CBD (Ghana).
  static const AppMapPoint _defaultCenter = AppMapPoint.accra;
  // LEGACY (Google backup — commented out for now):
  // static const LatLng _defaultCenterLegacy = LatLng(5.6037, -0.1870);

  /// Passed to [FormBuilder.initialValue] so edit mode always prefills.
  Map<String, dynamic> _initialValues = const {};
  bool _prefilled = false;

  bool get isEditing =>
      widget.addressId != null && widget.addressId!.isNotEmpty;

  bool get _hasPin => _latitude != null && _longitude != null;

  AppMapPoint get _mapCenter {
    if (_hasPin) return AppMapPoint(_latitude!, _longitude!);
    return _defaultCenter;
  }
  // LEGACY (Google backup — commented out for now):
  // LatLng get _mapCenterLegacy {
  //   if (_hasPin) return LatLng(_latitude!, _longitude!);
  //   return _defaultCenterLegacy;
  // }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _prefilled = true;
      // Best-effort: center on current location for new addresses.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _useCurrentLocation(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.addressId!;
    AddressModel? address;

    try {
      final book = await ref.read(addressBookProvider.future);
      for (final a in book.addresses) {
        if (a.id == id) {
          address = a;
          break;
        }
      }
    } catch (_) {
      // Address book may be empty/unavailable; try service fetch below.
    }

    address ??= await ref.read(addressServiceProvider).getAddress(id);

    if (!mounted) return;

    if (address == null) {
      setState(() {
        _loading = false;
        _prefilled = true;
      });
      Helpers.showErrorToast('Address not found');
      return;
    }

    setState(() {
      _isDefault = address!.isDefault;
      _type = address.addressType;
      _latitude = address.latitude;
      _longitude = address.longitude;
      _initialValues = {
        'label': address.label ?? '',
        'receiver': address.receiverName ?? '',
        'phone': address.phone ?? '',
        'line1': address.addressLine1,
        'line2': address.addressLine2 ?? '',
        'city': address.city,
        'state': address.state ?? '',
        'instructions': address.deliveryInstructions ?? '',
      };
      _loading = false;
      _prefilled = true;
    });

    // Move camera after map is ready (may already be created).
    // OSM: MapController.move (no API key).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasPin) {
        _mapController?.moveTo(AppMapPoint(_latitude!, _longitude!), 16);
        // LEGACY (Google backup — commented out for now):
        // _mapControllerLegacy?.animateCamera(
        //   CameraUpdate.newLatLngZoom(LatLng(_latitude!, _longitude!), 16),
        // );
      }
    });
  }

  void _setPin(AppMapPoint pos, {bool animate = false}) {
    setState(() {
      _latitude = pos.latitude;
      _longitude = pos.longitude;
    });
    if (animate) {
      // OSM move (mirrors Google animateCamera(newLatLngZoom)).
      _mapController?.moveTo(pos, 16);
      // LEGACY (Google backup — commented out for now):
      // _mapControllerLegacy?.animateCamera(
      //   CameraUpdate.newLatLngZoom(pos.toGoogle(), 16),
      // );
    }
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final loc = ref.read(locationServiceProvider);
      // OSM-first: prefer provider-neutral point (free, no key).
      AppMapPoint pos;
      try {
        pos = await loc.getCurrentMapPoint(forceRefresh: true);
      } catch (_) {
        // Fallback: legacy Google LatLng → convert (type only, no key).
        final legacy = await loc.getCurrentLatLng(forceRefresh: true);
        pos = AppMapPoint.fromGoogle(legacy);
      }
      if (!mounted) return;
      _setPin(pos, animate: true);
      if (!silent) {
        Helpers.showSuccessToast('Location set from GPS');
      }
    } catch (e) {
      if (!silent && mounted) {
        Helpers.showErrorToast(
          e is LocationException ? e.message : 'Could not get current location',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// SiteDrop-style full-screen picker: same center-pin UX, taller map,
  /// Confirm button writes the pin back to the form.
  Future<void> _openFullscreenPicker() async {
    final loc = ref.read(locationServiceProvider);
    final pickerController = AppMapController();
    AppMapPoint picked = _mapCenter;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetH = MediaQuery.sizeOf(sheetContext).height * 0.92;
        return Container(
          height: sheetH,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SiteDropMapPicker(
                initialPoint: _mapCenter,
                controller: pickerController,
                locationService: loc,
                enabled: !_saving,
                height: null,
                onPick: (pos) => picked = pos,
                onLocate: () async {
                  try {
                    final pos = await loc.getCurrentMapPoint(
                      forceRefresh: true,
                    );
                    pickerController.moveTo(pos, 16);
                    picked = pos;
                  } catch (e) {
                    if (sheetContext.mounted) {
                      Helpers.showErrorToast(
                        e is LocationException
                            ? e.message
                            : 'Could not get current location',
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Confirm this location'),
                ),
              ),
            ],
          ),
        );
      },
    );
    pickerController.dispose();
    if (!mounted) return;
    // Write the fullscreen pick back to the inline form pin.
    _setPin(picked);
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;

    if (!_hasPin) {
      Helpers.showErrorToast('Drag the map to set delivery coordinates');
      return;
    }

    final values = form.value;
    final auth = ref.read(authProvider);
    final user = auth is AsyncData && auth.value is AuthAuthenticated
        ? (auth.value as AuthAuthenticated).user
        : null;

    final model = AddressModel(
      id: widget.addressId ?? '',
      userId: user?.id ?? '',
      addressType: _type,
      label: _str(values['label']),
      addressLine1: values['line1']?.toString().trim() ?? '',
      addressLine2: _str(values['line2']),
      city: values['city']?.toString().trim() ?? '',
      state: _str(values['state']),
      country: 'Ghana',
      isDefault: _isDefault,
      deliveryInstructions: _str(values['instructions']),
      phone: values['phone']?.toString().trim() ?? '',
      receiverName: values['receiver']?.toString().trim() ?? '',
      latitude: _latitude,
      longitude: _longitude,
    );

    final errors = model.validate();
    if (errors.isNotEmpty) {
      Helpers.showErrorToast(errors.first);
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(addressServiceProvider);
      if (isEditing) {
        await service.updateAddress(model);
      } else {
        await service.createAddress(model);
      }

      if (!mounted) return;

      final message = isEditing ? 'Address updated' : 'Address saved';
      context.pop(true);
      Helpers.showSuccessToast(message);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Helpers.showErrorToast(e);
      }
    }
  }

  String? _str(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: appBarTitle(context, isEditing ? 'Edit Address' : 'Add Address'),
        backgroundColor: p.surface,
        elevation: 0,
        leading: const AppBackButton(fallbackRoute: RouteNames.addresses),
      ),
      body: _loading || !_prefilled
          ? const Center(child: CircularProgressIndicator())
          : FormBuilder(
              key: _formKey,
              initialValue: _initialValues,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _typePicker(p),
                  const SizedBox(height: 4),
                  _fbField(
                    name: 'label',
                    label: 'Label (Home, Office, Site)',
                  ),
                  _fbField(
                    name: 'receiver',
                    label: 'Receiver name',
                    validators: [
                      FormBuilderValidators.required(
                        errorText: 'Receiver name is required',
                      ),
                    ],
                  ),
                  _fbField(
                    name: 'phone',
                    label: 'Phone',
                    keyboard: TextInputType.phone,
                    validators: [Validators.phone],
                  ),
                  _fbField(
                    name: 'line1',
                    label: 'Street address',
                    validators: [
                      FormBuilderValidators.required(
                        errorText: 'Street address is required',
                      ),
                    ],
                  ),
                  _fbField(
                    name: 'line2',
                    label: 'Apartment / landmark (optional)',
                  ),
                  _fbField(
                    name: 'city',
                    label: 'City',
                    validators: [
                      FormBuilderValidators.required(
                        errorText: 'City is required',
                      ),
                    ],
                  ),
                  _fbField(
                    name: 'state',
                    label: 'Region / State (optional)',
                  ),
                  _fbField(
                    name: 'instructions',
                    label: 'Delivery instructions (optional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  _mapSection(p),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Set as default',
                      style: TextStyle(color: p.textPrimary),
                    ),
                    value: _isDefault,
                    activeThumbColor: AppColors.primary,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _isDefault = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_saving ? 'Saving…' : 'Save address'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _mapSection(AppPalette p) {
    final coordsLabel = _hasPin
        ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
        : 'Not set — drag the map or search to place the pin';
    final locationService = ref.read(locationServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Delivery location',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: (_saving || _locating) ? null : () => _useCurrentLocation(),
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_locating ? 'Locating…' : 'Use GPS'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Drag the map under the pin, tap, or search — like SiteDrop/SiteDrop. Coordinates are saved for delivery.',
          style: TextStyle(fontSize: 12, color: p.textMuted),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hasPin ? AppColors.primary.withValues(alpha: 0.45) : p.border,
              width: _hasPin ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          // SiteDrop/SiteDrop-style picker (OSM, free, no key): center pin, search,
          // GPS + zoom controls, bottom address card.
          child: SiteDropMapPicker(
            initialPoint: _mapCenter,
            controller: _mapController ??= AppMapController(),
            locationService: locationService,
            enabled: !_saving,
            locating: _locating,
            height: 380,
            onPick: (pos) => _setPin(pos),
            onLocate: (_saving || _locating) ? null : () => _useCurrentLocation(),
            onExpand: () => _openFullscreenPicker(),
          ),
          // LEGACY (Google backup — commented out for now, see git history
          // for the previous AppGoogleMap block; requires GOOGLE_MAPS_API_KEY).
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _hasPin ? Icons.check_circle : Icons.place_outlined,
              size: 16,
              color: _hasPin ? AppColors.success : p.iconMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                coordsLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _hasPin ? p.textSecondary : p.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (_hasPin)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _latitude = null;
                          _longitude = null;
                        }),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _typePicker(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Address type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AddressType.values.map((t) {
              final selected = _type == t;
              return ChoiceChip(
                label: Text(t.displayName),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _type = t),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : p.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primary : p.border,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _fbField({
    required String name,
    required String label,
    TextInputType? keyboard,
    int maxLines = 1,
    List<FormFieldValidator<String>> validators = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormBuilderTextField(
        name: name,
        initialValue: _initialValues[name]?.toString(),
        keyboardType: keyboard,
        maxLines: maxLines,
        enabled: !_saving,
        style: InputStyles.text(context),
        cursorColor: AppColors.primary,
        decoration: InputStyles.decoration(context, labelText: label),
        validator: validators.isEmpty
            ? null
            : FormBuilderValidators.compose(validators),
      ),
    );
  }
}
