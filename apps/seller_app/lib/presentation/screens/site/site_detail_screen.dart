// lib/presentation/screens/site/site_detail_screen.dart
// Site detail with tabs: Overview, Materials, Staff, Visits, Documents, Timeline.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/data/models/site.dart';
import 'package:sitedrop_core/data/models/site_document.dart';
import 'package:sitedrop_core/data/models/site_material.dart';
import 'package:sitedrop_core/data/models/site_staff.dart';
import 'package:sitedrop_core/data/models/site_visit.dart';
import 'package:sitedrop_core/data/models/site_status_log.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../providers/site_provider.dart';

class SiteDetailScreen extends ConsumerStatefulWidget {
  final String siteId;

  const SiteDetailScreen({super.key, required this.siteId});

  @override
  ConsumerState<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends ConsumerState<SiteDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final siteAsync = ref.watch(siteDetailProvider(widget.siteId));

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: siteAsync.when(
          data: (site) => Text(
            site?.name ?? 'Site Details',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Error'),
        ),
        leading: const AppBackButton(fallbackRoute: RouteNames.sitesManagement),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Site'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: p.textMuted,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Materials'),
            Tab(text: 'Staff'),
            Tab(text: 'Visits'),
            Tab(text: 'Documents'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: siteAsync.when(
        loading: () => const LoadingWidget(message: 'Loading site…'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (site) {
          if (site == null) return _buildNotFound(context);
          return Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddDialog(context, site),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context, site),
                _buildMaterialsTab(context, site),
                _buildStaffTab(context, site),
                _buildVisitsTab(context, site),
                _buildDocumentsTab(context, site),
                _buildTimelineTab(context, site),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleAction(String value) {
    switch (value) {
      case 'edit':
        context.push(RouteNames.editSiteWithId(widget.siteId));
        break;
      case 'delete':
        _confirmDelete(context);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Site?'),
        content: const Text('This will permanently delete the site and all associated data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await SiteService.deleteSite(widget.siteId);
        if (context.mounted) {
          context.go(RouteNames.sitesManagement);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }
  }

  void _showAddDialog(BuildContext context, SiteModel site) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add New',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _AddOption(
                icon: Icons.construction_outlined,
                title: 'Material',
                subtitle: 'Track material deliveries',
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RouteNames.addSiteMaterialWithId(site.id));
                },
              ),
              _AddOption(
                icon: Icons.person_add_outlined,
                title: 'Staff Member',
                subtitle: 'Add worker to this site',
                color: const Color(0xFF6366F1),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RouteNames.addSiteStaffWithId(site.id));
                },
              ),
              _AddOption(
                icon: Icons.how_to_reg_outlined,
                title: 'Visit',
                subtitle: 'Schedule a site visit',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RouteNames.addSiteVisitWithId(site.id));
                },
              ),
              _AddOption(
                icon: Icons.description_outlined,
                title: 'Document',
                subtitle: 'Upload permit, contract, etc.',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RouteNames.addSiteDocumentWithId(site.id));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city_outlined, size: 64, color: p.iconMuted),
            const SizedBox(height: 16),
            Text('Site not found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 8),
            Text('This site may have been removed', style: TextStyle(color: p.textMuted, fontSize: 15)),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.go(RouteNames.sitesManagement), child: const Text('Back to Sites')),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, SiteModel site) {
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(siteDetailProvider(widget.siteId).future),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: site.siteType.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(site.siteType.icon, color: site.siteType.color, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: p.textPrimary)),
                              const SizedBox(height: 4),
                              _StatusChip(color: site.status.color, label: site.status.displayName),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(site.siteType.displayName, style: TextStyle(fontSize: 14, color: p.textMuted)),
                    const SizedBox(height: 12),
                    Text(site.address, style: TextStyle(fontSize: 14, color: p.textSecondary)),
                    if (site.contactPerson != null || site.contactPhone != null) ...[
                      const SizedBox(height: 12),
                      if (site.contactPerson != null)
                        _infoRow(Icons.person_outline, 'Contact', site.contactPerson!),
                      if (site.contactPhone != null)
                        _infoRow(Icons.phone_outlined, 'Phone', site.contactPhone!),
                    ],
                    if (site.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text('Description', style: _sectionStyle(p)),
                      const SizedBox(height: 4),
                      Text(site.description!, style: TextStyle(fontSize: 13, color: p.textSecondary)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  label: 'Priority',
                  value: site.priorityLevel.displayName,
                  icon: Icons.priority_high_outlined,
                  color: site.priorityLevel.color,
                ),
                if (site.sizeSqMeters != null)
                  _StatCard(
                    label: 'Area',
                    value: '${site.sizeSqMeters!.toStringAsFixed(0)} m²',
                    icon: Icons.straighten_outlined,
                    color: AppColors.primary,
                  ),
                if (site.budget != null)
                  _StatCard(
                    label: 'Budget',
                    value: Formatters.formatCurrency(site.budget!),
                    icon: Icons.attach_money_outlined,
                    color: const Color(0xFF10B981),
                  ),
                if (site.estimatedCompletionDate != null)
                  _StatCard(
                    label: 'Est. Completion',
                    value: Formatters.formatDate(site.estimatedCompletionDate!),
                    icon: Icons.calendar_today_outlined,
                    color: const Color(0xFF8B5CF6),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions', style: _sectionStyle(p)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RouteNames.addSiteMaterialWithId(site.id)),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add Material'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RouteNames.addSiteStaffWithId(site.id)),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Add Staff'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RouteNames.addSiteVisitWithId(site.id)),
                            icon: const Icon(Icons.how_to_reg_outlined),
                            label: const Text('Schedule Visit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RouteNames.addSiteDocumentWithId(site.id)),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Upload Document'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsTab(BuildContext context, SiteModel site) {
    final materialsAsync = ref.watch(siteMaterialsProvider(site.id));

    return materialsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading materials…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (materials) {
        if (materials.isEmpty) {
          return _buildEmptyState(
            context,
            'No materials yet',
            'Add materials to track deliveries',
            Icons.inventory_2_outlined,
            () => context.push(RouteNames.addSiteMaterialWithId(site.id)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(siteMaterialsProvider(site.id).future),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) => _MaterialCard(material: materials[index], siteId: site.id),
          ),
        );
      },
    );
  }

  Widget _buildStaffTab(BuildContext context, SiteModel site) {
    final staffAsync = ref.watch(siteStaffProvider((siteId: site.id, isActive: null)));

    return staffAsync.when(
      loading: () => const LoadingWidget(message: 'Loading staff…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (staff) {
        if (staff.isEmpty) {
          return _buildEmptyState(
            context,
            'No staff assigned',
            'Add workers to this site',
            Icons.people_outline,
            () => context.push(RouteNames.addSiteStaffWithId(site.id)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(siteStaffProvider((siteId: site.id, isActive: null)).future),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            itemBuilder: (context, index) => _StaffCard(staff: staff[index]),
          ),
        );
      },
    );
  }

  Widget _buildVisitsTab(BuildContext context, SiteModel site) {
    final visitsAsync = ref.watch(siteVisitsProvider((siteId: site.id, status: null)));

    return visitsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading visits…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (visits) {
        if (visits.isEmpty) {
          return _buildEmptyState(
            context,
            'No visits scheduled',
            'Schedule site visits for inspections',
            Icons.event_outlined,
            () => context.push(RouteNames.addSiteVisitWithId(site.id)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(siteVisitsProvider((siteId: site.id, status: null)).future),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            itemBuilder: (context, index) => _VisitCard(visit: visits[index]),
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab(BuildContext context, SiteModel site) {
    final docsAsync = ref.watch(siteDocumentsProvider(site.id));

    return docsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading documents…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (docs) {
        if (docs.isEmpty) {
          return _buildEmptyState(
            context,
            'No documents',
            'Upload permits, contracts, and reports',
            Icons.description_outlined,
            () => context.push(RouteNames.addSiteDocumentWithId(site.id)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(siteDocumentsProvider(site.id).future),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _DocumentCard(doc: docs[index]),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTab(BuildContext context, SiteModel site) {
    final logsAsync = ref.watch(siteStatusLogsProvider(site.id));

    return logsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading timeline…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return _buildEmptyState(
            context,
            'No status changes',
            'Status history will appear here',
            Icons.history_outlined,
            null,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(siteStatusLogsProvider(site.id).future),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) => _LogCard(log: logs[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle, IconData icon, VoidCallback? onAction) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: p.surfaceMuted, shape: BoxShape.circle),
              child: Icon(icon, size: 50, color: p.iconMuted),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 14)),
            if (onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: const Text('Add')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 13, color: p.textMuted, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.textPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  TextStyle _sectionStyle(AppPalette p) => TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.textPrimary);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.divider)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.textPrimary)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final SiteMaterialModel material;
  final String siteId;

  const _MaterialCard({required this.material, required this.siteId});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.divider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: material.deliveryStatus.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(material.deliveryStatus.icon, color: material.deliveryStatus.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.materialName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${material.quantityDelivered}/${material.quantityNeeded} ${material.unit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textMuted)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: material.deliveryProgress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: p.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation(material.deliveryStatus.color),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                Formatters.formatCurrency(material.actualCost ?? material.estimatedCost ?? 0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final SiteStaffModel staff;

  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.divider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: staff.role.color.withValues(alpha: 0.12),
              child: Icon(staff.role.icon, color: staff.role.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.position, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.textPrimary)),
                  const SizedBox(height: 2),
                  Text(staff.role.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: staff.isActive ? AppColors.success : AppColors.error, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(staff.isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 11, color: staff.isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            if (staff.performanceRating != null)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(staff.performanceRating!.toStringAsFixed(1), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final SiteVisitModel visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.divider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visit.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(visit.status.icon, color: visit.status.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.visitorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.textPrimary)),
                  const SizedBox(height: 2),
                  Text(visit.purpose, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textMuted)),
                  const SizedBox(height: 4),
                  Text(Formatters.formatDateTime(visit.visitDate), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.textMuted)),
                ],
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusChip(color: visit.status.color, label: visit.status.displayName),
                  const SizedBox(height: 4),
                  if (visit.checkInTime != null)
                    Text('In: ${Formatters.formatDateTime(visit.checkInTime!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: p.textMuted)),
                  if (visit.checkOutTime != null)
                    Text('Out: ${Formatters.formatDateTime(visit.checkOutTime!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: p.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final SiteDocumentModel doc;

  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.divider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: doc.documentType.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(doc.documentType.icon, color: doc.documentType.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.textPrimary)),
                  const SizedBox(height: 2),
                  Text(doc.documentType.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(child: _StatusChip(color: doc.status.color, label: doc.status.displayName)),
                      const SizedBox(width: 8),
                      if (doc.isConfidential)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text('Confidential', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.error)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                Formatters.formatDate(doc.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final SiteStatusLogModel log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.divider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.history, color: p.iconMuted, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.oldStatus != null)
                    Row(
                      children: [
                        Flexible(child: Text(log.oldStatus!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textMuted, decoration: TextDecoration.lineThrough))),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 14, color: p.textMuted),
                        const SizedBox(width: 8),
                      ],
                    ),
                  Text(
                    log.newStatus,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  if (log.reason != null) ...[
                    Text('Reason: ${log.reason}', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textMuted)),
                    const SizedBox(height: 2),
                  ],
                  Text(Formatters.formatDateTime(log.createdAt), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(color: p.textMuted)),
      trailing: Icon(Icons.chevron_right, color: p.iconMuted),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

extension SiteDocumentTypeExtension on DocumentType {
  Color get color {
    switch (this) {
      case DocumentType.permit:
        return const Color(0xFF10B981);
      case DocumentType.contract:
        return const Color(0xFF8B5CF6);
      case DocumentType.blueprint:
        return const Color(0xFF6366F1);
      case DocumentType.report:
        return const Color(0xFFF59E0B);
      case DocumentType.invoice:
        return AppColors.primary;
      case DocumentType.insurance:
        return const Color(0xFFEC4899);
      case DocumentType.certificate:
        return const Color(0xFF06B6D4);
      case DocumentType.other:
        return const Color(0xFF64748B);
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.permit:
        return Icons.verified_outlined;
      case DocumentType.contract:
        return Icons.description_outlined;
      case DocumentType.blueprint:
        return Icons.map_outlined;
      case DocumentType.report:
        return Icons.assessment_outlined;
      case DocumentType.invoice:
        return Icons.receipt_outlined;
      case DocumentType.insurance:
        return Icons.security_outlined;
      case DocumentType.certificate:
        return Icons.card_membership_outlined;
      case DocumentType.other:
        return Icons.insert_drive_file_outlined;
    }
  }
}

extension DocumentStatusExtension on DocumentStatus {
  Color get color {
    switch (this) {
      case DocumentStatus.draft:
        return const Color(0xFF64748B);
      case DocumentStatus.active:
        return AppColors.success;
      case DocumentStatus.archived:
        return const Color(0xFF64748B);
      case DocumentStatus.expired:
        return AppColors.error;
      case DocumentStatus.rejected:
        return AppColors.error;
    }
  }
}

extension SiteMaterialDeliveryStatusExtension on DeliveryStatus {
  Color get color {
    switch (this) {
      case DeliveryStatus.pending:
        return AppColors.warning;
      case DeliveryStatus.partial:
        return const Color(0xFF6366F1);
      case DeliveryStatus.completed:
        return AppColors.success;
    }
  }

  IconData get icon {
    switch (this) {
      case DeliveryStatus.pending:
        return Icons.schedule_outlined;
      case DeliveryStatus.partial:
        return Icons.local_shipping_outlined;
      case DeliveryStatus.completed:
        return Icons.check_circle_outlined;
    }
  }
}

extension StaffRoleExtension on StaffRole {
  Color get color {
    switch (this) {
      case StaffRole.siteManager:
        return const Color(0xFF6366F1);
      case StaffRole.supervisor:
        return const Color(0xFF8B5CF6);
      case StaffRole.foreman:
        return const Color(0xFF10B981);
      case StaffRole.safetyOfficer:
        return AppColors.warning;
      case StaffRole.qualityControl:
        return const Color(0xFFEC4899);
      case StaffRole.operator:
        return const Color(0xFF06B6D4);
      case StaffRole.laborer:
        return const Color(0xFF64748B);
      case StaffRole.other:
        return const Color(0xFF94A3B8);
    }
  }

  IconData get icon {
    switch (this) {
      case StaffRole.siteManager:
        return Icons.manage_accounts_outlined;
      case StaffRole.supervisor:
        return Icons.supervisor_account_outlined;
      case StaffRole.foreman:
        return Icons.construction_outlined;
      case StaffRole.safetyOfficer:
        return Icons.shield_outlined;
      case StaffRole.qualityControl:
        return Icons.verified_outlined;
      case StaffRole.operator:
        return Icons.precision_manufacturing_outlined;
      case StaffRole.laborer:
        return Icons.person_outline;
      case StaffRole.other:
        return Icons.help_outline;
    }
  }
}

extension VisitStatusExtension on VisitStatus {
  Color get color {
    switch (this) {
      case VisitStatus.scheduled:
        return const Color(0xFF6366F1);
      case VisitStatus.checkedIn:
        return const Color(0xFF10B981);
      case VisitStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case VisitStatus.completed:
        return AppColors.success;
      case VisitStatus.cancelled:
        return AppColors.error;
      case VisitStatus.rejected:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case VisitStatus.scheduled:
        return Icons.calendar_today_outlined;
      case VisitStatus.checkedIn:
        return Icons.login_outlined;
      case VisitStatus.inProgress:
        return Icons.work_outline;
      case VisitStatus.completed:
        return Icons.check_circle_outlined;
      case VisitStatus.cancelled:
        return Icons.cancel_outlined;
      case VisitStatus.rejected:
        return Icons.block_outlined;
    }
  }
}