// lib/presentation/screens/truck/add_edit_truck_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/services/truck_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class AddEditTruckScreen extends ConsumerStatefulWidget {
  final String? truckId;
  const AddEditTruckScreen({super.key, this.truckId});

  @override
  ConsumerState<AddEditTruckScreen> createState() => _AddEditTruckScreenState();
}

class _AddEditTruckScreenState extends ConsumerState<AddEditTruckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _capacityController = TextEditingController();

  bool _loading = false;
  bool _loadingTruck = false;
  bool get _isEditing => widget.truckId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadTruck();
  }

  Future<void> _loadTruck() async {
    setState(() => _loadingTruck = true);
    try {
      // Placeholder: TruckService does not have fetch by id, assume list contains it
      // For now just show empty form
    } finally {
      if (mounted) setState(() => _loadingTruck = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String? userId;
      ref.read(authProvider).when(
        data: (state) {
          if (state is AuthAuthenticated) userId = state.user.id;
        },
        loading: () {},
        error: (_, _) {},
      );
      if (userId == null) {
        Helpers.showErrorToast('Please sign in');
        return;
      }
      final payload = {
        'registration_number': _regController.text.trim(),
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.tryParse(_yearController.text.trim()) ?? 0,
        'capacity_tons': double.tryParse(_capacityController.text.trim()) ?? 0,
        'vehicle_type': 'truck',
        'user_id': userId,
      };
      final (ok, message, _) = await TruckService.createTruck(payload);
      if (ok) {
        Helpers.showSuccessToast(message);
        if (mounted) context.pop();
      } else {
        Helpers.showErrorToast(message);
      }
    } catch (e) {
      Helpers.showErrorToast(Helpers.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Truck' : 'Add Truck', style: TextStyle(color: p.textPrimary)),
        leading: const AppBackButton(fallbackRoute: RouteNames.trucksManagement),
      ),
      body: _loadingTruck
          ? const LoadingWidget(message: 'Loading truck…')
          : _loading
              ? const LoadingWidget(message: 'Saving…')
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildField(_regController, 'Registration Number *', validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 16),
                      _buildField(_makeController, 'Make *', validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 16),
                      _buildField(_modelController, 'Model *', validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 16),
                      _buildField(_yearController, 'Year', keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      _buildField(_capacityController, 'Capacity Tons', keyboardType: TextInputType.numberWithOptions(decimal: true)),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _save,
                        child: Text(_isEditing ? 'Update Truck' : 'Create Truck'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: label),
      validator: validator,
    );
  }
}
