// lib/presentation/screens/driver/truck_detail_screen.dart
// One truck's full fleet record: details, documents, insurance,
// maintenance, trip logs + activity history (TruckMatcher inputs).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/truck.dart';
import 'package:sitedrop_core/data/models/truck_document.dart';
import 'package:sitedrop_core/data/models/truck_insurance.dart';
import 'package:sitedrop_core/data/models/truck_log.dart';
import 'package:sitedrop_core/data/models/truck_maintenance.dart';
import 'package:sitedrop_core/data/models/trip.dart';
import 'package:sitedrop_core/data/services/truck_service.dart';
import '../../providers/truck_provider.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_dropdown.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_text_field.dart';

const _docTypes = [
  'insurance',
  'registration',
  'road_worthy',
  'permit',
  'inspection',
  'license',
  'other',
];

const _insuranceTypes = [
  'comprehensive',
  'third_party',
  'motor_accident',
  'fire_theft',
  'public_liability',
  'goods_transit',
  'other',
];

const _frequencies = ['monthly', 'quarterly', 'biannually', 'annually'];
const _maintenanceTypes = ['routine', 'repair', 'emergency'];

class TruckDetailScreen extends ConsumerStatefulWidget {
  final TruckModel truck;

  const TruckDetailScreen({super.key, required this.truck});

  @override
  ConsumerState<TruckDetailScreen> createState() =>
      _TruckDetailScreenState();
}

class _TruckDetailScreenState extends ConsumerState<TruckDetailScreen> {
  String get _truckId => widget.truck.id;

  /// Sheet-owned controllers live here (not method-local): disposing them
  /// at sheet close races the exit-animation rebuild ("used after
  /// dispose"). The screen outlives every sheet, so teardown is safe.
  final List<TextEditingController> _sheetControllers = [];

  TextEditingController _sheetController([String? text]) {
    final c = TextEditingController(text: text);
    _sheetControllers.add(c);
    return c;
  }

  @override
  void dispose() {
    for (final c in _sheetControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshAll() async {
    ref.invalidate(truckDocumentsProvider(_truckId));
    ref.invalidate(truckInsuranceProvider(_truckId));
    ref.invalidate(truckMaintenanceProvider(_truckId));
    ref.invalidate(truckLogsProvider(_truckId));
    ref.invalidate(truckTripsProvider(_truckId));
    ref.invalidate(myTrucksProvider);
    try {
      await Future.wait([
        ref.read(truckDocumentsProvider(_truckId).future),
        ref.read(truckInsuranceProvider(_truckId).future),
        ref.read(truckMaintenanceProvider(_truckId).future),
        ref.read(truckLogsProvider(_truckId).future),
        ref.read(truckTripsProvider(_truckId).future),
      ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(truckDocumentsProvider(_truckId));
    final insuranceAsync = ref.watch(truckInsuranceProvider(_truckId));
    final maintenanceAsync = ref.watch(truckMaintenanceProvider(_truckId));
    final logsAsync = ref.watch(truckLogsProvider(_truckId));
    final tripsAsync = ref.watch(truckTripsProvider(_truckId));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, widget.truck.displayName),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.driverTrucks,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _matcherCard(context),
              const SizedBox(height: 16),
              _detailsCard(context),
              const SizedBox(height: 16),
              _section(
                context,
                'Documents',
                Icons.folder_outlined,
                trailing: TextButton.icon(
                  onPressed: () => _uploadDocumentSheet(),
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('Upload'),
                ),
                child: docsAsync.when(
                  data: (docs) => docs.isEmpty
                      ? _emptyLine(
                          context,
                          'No documents yet — upload registration, insurance or permits.',
                        )
                      : Column(
                          children: [
                            for (final d in docs) ...[
                              _docTile(context, d),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                  loading: () => const LoadingWidget.compact(),
                  error: (e, _) => _errorLine(
                    context,
                    () => ref.invalidate(
                      truckDocumentsProvider(_truckId),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section(
                context,
                'Insurance',
                Icons.verified_user_outlined,
                trailing: insuranceAsync.asData?.value != null
                    ? TextButton.icon(
                        onPressed: () => _insuranceSheet(
                          insuranceAsync.asData!.value,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      )
                    : null,
                child: insuranceAsync.when(
                  data: (ins) => ins == null
                      ? _emptyAction(
                          context,
                          'No insurance policy — matching needs active cover.',
                          'Add insurance',
                          () => _insuranceSheet(null),
                        )
                      : _insuranceCard(context, ins),
                  loading: () => const LoadingWidget.compact(),
                  error: (e, _) => _errorLine(
                    context,
                    () => ref.invalidate(
                      truckInsuranceProvider(_truckId),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section(
                context,
                'Maintenance',
                Icons.build_outlined,
                trailing: TextButton.icon(
                  onPressed: _maintenanceSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log'),
                ),
                child: maintenanceAsync.when(
                  data: (rows) => rows.isEmpty
                      ? _emptyLine(
                          context,
                          'No maintenance logged yet.',
                        )
                      : Column(
                          children: [
                            for (final m in rows.take(5)) ...[
                              _maintenanceTile(context, m),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                  loading: () => const LoadingWidget.compact(),
                  error: (e, _) => _errorLine(
                    context,
                    () => ref.invalidate(
                      truckMaintenanceProvider(_truckId),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section(
                context,
                'Trips',
                Icons.route_outlined,
                child: tripsAsync.when(
                  data: (trips) => trips.isEmpty
                      ? _emptyLine(
                          context,
                          'No trips yet — created automatically when you accept and complete deliveries.',
                        )
                      : Column(
                          children: [
                            for (final t in trips.take(5)) ...[
                              _tripTile(context, t),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                  loading: () => const LoadingWidget.compact(),
                  error: (e, _) => _errorLine(
                    context,
                    () => ref.invalidate(truckTripsProvider(_truckId)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section(
                context,
                'History',
                Icons.history_outlined,
                child: logsAsync.when(
                  data: (logs) => logs.isEmpty
                      ? _emptyLine(context, 'No activity yet.')
                      : Column(
                          children: [
                            for (final l in logs.take(10)) ...[
                              _logTile(context, l),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                  loading: () => const LoadingWidget.compact(),
                  error: (e, _) => _errorLine(
                    context,
                    () => ref.invalidate(truckLogsProvider(_truckId)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MATCHER + DETAILS
  // ============================================================
  Widget _matcherCard(BuildContext context) {
    final t = widget.truck;
    final ready = t.matcherReady;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (ready ? Colors.green : Colors.orange)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (ready ? Colors.green : Colors.orange)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'Match-ready' : 'Action needed',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: ready ? Colors.green : Colors.orange,
                  ),
                ),
                if (t.blockerReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t.blockerReason!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push(
              RouteNames.driverTruckSetup,
              extra: t,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Edit details'),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(BuildContext context) {
    final t = widget.truck;
    String date(DateTime? d) => d == null
        ? '—'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return _section(
      context,
      'Details',
      Icons.local_shipping_outlined,
      child: Column(
        children: [
          _row('Registration', t.registrationNumber),
          _row('Make / Model', '${t.make} ${t.model} (${t.year})'),
          _row('Capacity', '${t.capacityTons} tons'),
          _row('Type', t.vehicleType.replaceAll('_', ' ')),
          _row('Fuel', t.fuelType ?? '—'),
          _row(
            'Mileage',
            t.currentMileage != null ? '${t.currentMileage} km' : '—',
          ),
          _row('Status', t.status.replaceAll('_', ' ')),
          _row('Verified', t.isVerified ? 'Yes' : 'Pending'),
          _row('Insurance expiry', date(t.insuranceExpiry)),
          if (t.notes?.isNotEmpty == true) _row('Notes', t.notes!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION SCAFFOLD
  // ============================================================
  Widget _section(
    BuildContext context,
    String title,
    IconData icon, {
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyLine(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, color: context.palette.textMuted),
    );
  }

  Widget _emptyAction(
    BuildContext context,
    String text,
    String button,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _emptyLine(context, text),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onTap, child: Text(button)),
      ],
    );
  }

  Widget _errorLine(BuildContext context, VoidCallback onRetry) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Could not load — pull to retry',
            style: TextStyle(fontSize: 13, color: context.palette.textMuted),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' || 'completed' => Colors.green,
      'pending' || 'scheduled' || 'in_progress' => Colors.orange,
      'expired' || 'failed' || 'cancelled' || 'rejected' => Colors.red,
      _ => Colors.grey,
    };
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // DOCUMENTS
  // ============================================================
  Widget _docTile(BuildContext context, TruckDocumentModel d) {
    final color = d.isExpired
        ? Colors.red
        : _statusColor(d.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              color: context.palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${d.typeLabel} · ${d.fileName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
                if (d.expiryDate != null)
                  Text(
                    d.isExpired
                        ? 'Expired'
                        : 'Expires ${d.expiryDate!.year}-${d.expiryDate!.month.toString().padLeft(2, '0')}-${d.expiryDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: d.isExpired ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          _pill(d.isExpired ? 'expired' : d.status, color),
          IconButton(
            tooltip: 'Delete document',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _confirmDeleteDocument(d),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDocument(TruckDocumentModel d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${d.title}" from this truck?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final (success, message) = await TruckService.deleteTruckDocument(
      truckId: _truckId,
      documentId: d.id,
    );
    if (!mounted) return;
    if (success) {
      ref.invalidate(truckDocumentsProvider(_truckId));
      ref.invalidate(truckLogsProvider(_truckId));
      Helpers.showSuccessToast(message);
    } else {
      Helpers.showErrorToast(message);
    }
  }

  Future<void> _uploadDocumentSheet() async {
    // NOTE: no TextEditingControllers — disposing a sheet-owned controller
    // at close races the exit animation rebuild ("used after dispose").
    var titleText = '';
    var expiryText = '';
    String docType = 'registration';
    XFile? picked;
    var busy = false;

    Future<void> pickExpiry(
      BuildContext cxt,
      void Function(void Function()) setSheet,
    ) async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: cxt,
        initialDate: now.add(const Duration(days: 365)),
        firstDate: now.subtract(const Duration(days: 365 * 5)),
        lastDate: now.add(const Duration(days: 365 * 10)),
      );
      if (date != null) {
        setSheet(() {
          expiryText =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text(
                'Upload document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              CustomDropdown<String>(
                label: 'Document type',
                value: docType,
                items: _docTypes
                    .map((t) => {
                          'value': t,
                          'label': t.replaceAll('_', ' '),
                        })
                    .toList(),
                onChanged: (v) => setSheet(() => docType = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Title',
                hint: 'e.g. Road worthy certificate',
                onChanged: (v) => titleText = v,
              ),
              const SizedBox(height: 12),
              _dateRow(
                context,
                label: 'Expiry date (optional)',
                value: expiryText.isEmpty ? 'YYYY-MM-DD' : expiryText,
                onTap: () => pickExpiry(sheetContext, setSheet),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          final file =
                              await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 2000,
                            imageQuality: 85,
                          );
                          if (file != null) {
                            setSheet(() => picked = file);
                          }
                        } catch (_) {
                          if (sheetContext.mounted) {
                            Helpers.showErrorToast(
                              'Could not pick a file',
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.attach_file),
                label: Text(
                  picked == null ? 'Choose file (PDF/image)' : picked!.name,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (titleText.trim().isEmpty) {
                          Helpers.showErrorToast('Add a title');
                          return;
                        }
                        if (picked == null) {
                          Helpers.showErrorToast('Choose a file first');
                          return;
                        }
                        setSheet(() => busy = true);
                        final (ok, message) =
                            await TruckService.uploadTruckDocument(
                          truckId: _truckId,
                          filePath: picked!.path,
                          fileName: picked!.name,
                          documentType: docType,
                          title: titleText.trim(),
                          expiryDate: expiryText.trim().isEmpty
                              ? null
                              : expiryText.trim(),
                        );
                        if (!mounted) return;
                        Navigator.pop(sheet);
                        if (ok) {
                          ref.invalidate(
                            truckDocumentsProvider(_truckId),
                          );
                          ref.invalidate(truckLogsProvider(_truckId));
                          Helpers.showSuccessToast(message);
                        } else {
                          Helpers.showErrorToast(message);
                        }
                      },
                isLoading: busy,
                text: 'Upload',
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tappable date row (controller-free alternative to a date TextField).
  Widget _dateRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: value == 'YYYY-MM-DD'
                          ? context.palette.textMuted
                          : context.palette.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: context.palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INSURANCE
  // ============================================================
  Widget _insuranceCard(BuildContext context, TruckInsuranceModel ins) {
    String date(DateTime? d) => d == null
        ? '—'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ins.insuranceCompany,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            _pill(
              ins.isActive ? 'active' : ins.status,
              ins.isActive ? Colors.green : Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _row('Policy', ins.policyNumber),
        _row('Type', ins.typeLabel),
        _row(
          'Cover',
          '${date(ins.coverageStartDate)} → ${date(ins.coverageEndDate)}',
        ),
        if (ins.premiumAmount != null)
          _row(
            'Premium',
            '${ins.premiumCurrency} ${ins.premiumAmount!.toStringAsFixed(2)} / ${ins.paymentFrequency}',
          ),
        if ((ins.agentPhone ?? '').isNotEmpty)
          _row('Agent', ins.agentPhone!),
      ],
    );
  }

  Future<void> _insuranceSheet(TruckInsuranceModel? existing) async {
    // Prefilled edit values live in State-tracked controllers (safe).
    final policy = _sheetController(existing?.policyNumber ?? '');
    final company =
        _sheetController(existing?.insuranceCompany ?? '');
    final premium = _sheetController(
      existing?.premiumAmount != null ? '${existing!.premiumAmount}' : '',
    );
    final agent = _sheetController(existing?.agentPhone ?? '');
    final start = _sheetController(_fmtDate(existing?.coverageStartDate));
    final end = _sheetController(_fmtDate(existing?.coverageEndDate));
    String type = existing?.type ?? 'comprehensive';
    String frequency = existing?.paymentFrequency ?? 'annually';
    var busy = false;

    Future<void> pickInto(
      TextEditingController c,
      BuildContext cxt, {
      required bool futureOnly,
    }) async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: cxt,
        initialDate: now,
        firstDate: futureOnly
            ? now
            : now.subtract(const Duration(days: 365 * 5)),
        lastDate: now.add(const Duration(days: 365 * 10)),
      );
      if (date != null) c.text = _fmtDate(date);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'Add insurance' : 'Edit insurance',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: policy,
                label: 'Policy number',
                hint: 'e.g. POL-2026-001',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: company,
                label: 'Insurance company',
                hint: 'e.g. SIC Insurance',
              ),
              const SizedBox(height: 12),
              CustomDropdown<String>(
                label: 'Cover type',
                value: type,
                items: _insuranceTypes
                    .map((t) => {
                          'value': t,
                          'label': t.replaceAll('_', ' '),
                        })
                    .toList(),
                onChanged: (v) => setSheet(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: start,
                      label: 'Cover start',
                      hint: 'YYYY-MM-DD',
                      readOnly: true,
                      onTap: () => pickInto(start, sheetContext,
                          futureOnly: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: end,
                      label: 'Cover end',
                      hint: 'YYYY-MM-DD',
                      readOnly: true,
                      onTap: () =>
                          pickInto(end, sheetContext, futureOnly: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: premium,
                      label: 'Premium (GHS)',
                      hint: 'e.g. 2500',
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomDropdown<String>(
                      label: 'Frequency',
                      value: frequency,
                      items: _frequencies
                          .map((f) => {'value': f, 'label': f})
                          .toList(),
                      onChanged: (v) =>
                          setSheet(() => frequency = v ?? frequency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: agent,
                label: 'Agent phone (optional)',
                hint: 'e.g. 0241234567',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (policy.text.trim().isEmpty ||
                            company.text.trim().isEmpty ||
                            start.text.trim().isEmpty ||
                            end.text.trim().isEmpty) {
                          Helpers.showErrorToast(
                            'Policy, company and cover dates are required',
                          );
                          return;
                        }
                        setSheet(() => busy = true);
                        final (ok, message) =
                            await TruckService.saveTruckInsurance(
                          truckId: _truckId,
                          insuranceId: existing?.id,
                          payload: {
                            'policy_number': policy.text.trim(),
                            'insurance_company': company.text.trim(),
                            'type': type,
                            'coverage_start_date': start.text.trim(),
                            'coverage_end_date': end.text.trim(),
                            if (premium.text.trim().isNotEmpty)
                              'premium_amount': double.tryParse(
                                    premium.text.trim(),
                                  ) ??
                                  0,
                            'payment_frequency': frequency,
                            if (agent.text.trim().isNotEmpty)
                              'agent_phone': agent.text.trim(),
                            if (existing == null) 'status': 'active',
                          },
                        );
                        if (!mounted) return;
                        Navigator.pop(sheet);
                        if (ok) {
                          ref.invalidate(
                            truckInsuranceProvider(_truckId),
                          );
                          ref.invalidate(truckLogsProvider(_truckId));
                          ref.invalidate(myTrucksProvider);
                          Helpers.showSuccessToast(message);
                        } else {
                          Helpers.showErrorToast(message);
                        }
                      },
                isLoading: busy,
                text: existing == null ? 'Add insurance' : 'Save changes',
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // MAINTENANCE
  // ============================================================
  Widget _maintenanceTile(BuildContext context, TruckMaintenanceModel m) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.typeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _pill(m.status, _statusColor(m.status)),
            ],
          ),
          if ((m.description ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                m.description!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                if (m.performedAt != null)
                  Helpers.formatDate(m.performedAt!),
                if (m.cost != null)
                  'GHS ${m.cost!.toStringAsFixed(2)}',
                if (m.mileageAtService != null)
                  '${m.mileageAtService!.toStringAsFixed(0)} km',
              ].join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _maintenanceSheet() async {
    // NOTE: no TextEditingControllers — disposing a sheet-owned controller
    // at close races the exit animation rebuild ("used after dispose").
    var descText = '';
    var costText = '';
    var mileageText = '';
    var performedText = _fmtDate(DateTime.now());
    String type = 'routine';
    var busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(sheetContext).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text(
                'Log maintenance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              CustomDropdown<String>(
                label: 'Type',
                value: type,
                items: _maintenanceTypes
                    .map((t) => {'value': t, 'label': t})
                    .toList(),
                onChanged: (v) => setSheet(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Description',
                hint: 'e.g. Oil change and brake check',
                maxLines: 2,
                onChanged: (v) => descText = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Cost (GHS, optional)',
                      hint: 'e.g. 850',
                      onChanged: (v) => costText = v,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Mileage (optional)',
                      hint: 'e.g. 120000',
                      onChanged: (v) => mileageText = v,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _dateRow(
                context,
                label: 'Performed on',
                value: performedText.isEmpty
                    ? 'YYYY-MM-DD'
                    : performedText,
                onTap: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: sheetContext,
                    initialDate: now,
                    firstDate: now.subtract(
                      const Duration(days: 365 * 10),
                    ),
                    lastDate: now,
                  );
                  if (date != null) {
                    setSheet(() => performedText = _fmtDate(date));
                  }
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (descText.trim().isEmpty) {
                          Helpers.showErrorToast('Add a description');
                          return;
                        }
                        setSheet(() => busy = true);
                        final (ok, message) =
                            await TruckService.addTruckMaintenance(
                          truckId: _truckId,
                          payload: {
                            'maintenance_type': type,
                            'description': descText.trim(),
                            'performed_at': performedText.trim().isEmpty
                                ? _fmtDate(DateTime.now())
                                : performedText.trim(),
                            if (costText.trim().isNotEmpty)
                              'cost': double.tryParse(
                                    costText.trim(),
                                  ) ??
                                  0,
                            if (mileageText.trim().isNotEmpty)
                              'mileage_at_service': double.tryParse(
                                    mileageText.trim(),
                                  ) ??
                                  0,
                          },
                        );
                        if (!mounted) return;
                        Navigator.pop(sheet);
                        if (ok) {
                          ref.invalidate(
                            truckMaintenanceProvider(_truckId),
                          );
                          ref.invalidate(truckLogsProvider(_truckId));
                          Helpers.showSuccessToast(message);
                        } else {
                          Helpers.showErrorToast(message);
                        }
                      },
                isLoading: busy,
                text: 'Save record',
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }

  // ============================================================
  // TRIPS + HISTORY
  // ============================================================
  Widget _tripTile(BuildContext context, TripModel t) {
    final status = t.status;
    final dist = t.distanceKm != null
        ? '${t.distanceKm!.toStringAsFixed(1)} km'
        : '—';
    final when =
        t.startedAt != null ? Helpers.formatDate(t.startedAt!) : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.orderId != null
                      ? 'Order trip · ${t.orderId}'
                      : 'Trip ${t.id}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$dist${when.isNotEmpty ? ' · $when' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _pill(status.replaceAll('_', ' '), _statusColor(status)),
        ],
      ),
    );
  }

  Widget _logTile(BuildContext context, TruckLogModel l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.palette.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.history_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if ((l.description ?? '').isNotEmpty)
                  Text(
                    l.description!,
                    style: const TextStyle(fontSize: 13),
                  ),
                Text(
                  [
                    if (l.createdAt != null)
                      Helpers.formatDate(l.createdAt!),
                    if ((l.userName ?? '').isNotEmpty) l.userName!,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
