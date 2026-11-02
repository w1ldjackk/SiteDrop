// lib/presentation/screens/buyer/sites_management_screen.dart
// Buyer construction sites management — list, create, edit sites.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/data/models/site.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../providers/auth_provider.dart';

class BuyerSitesManagementScreen extends ConsumerStatefulWidget {
  const BuyerSitesManagementScreen({super.key});

  @override
  ConsumerState<BuyerSitesManagementScreen> createState() =>
      _BuyerSitesManagementScreenState();
}

class _BuyerSitesManagementScreenState
    extends ConsumerState<BuyerSitesManagementScreen> {
  SiteStatus? _filterStatus;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  final List<SiteModel> _sites = [];

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _sites.clear();
      _hasMore = true;
      setState(() => _isLoading = true);
    }
    if (!_hasMore) return;

    String? userId;
    ref.read(authProvider).when(
      data: (state) {
        if (state is AuthAuthenticated) {
          userId = state.user.id;
        }
      },
      loading: () {},
      error: (_, _) {},
    );
    if (userId == null) return;

    try {
      final newSites = await SiteService.fetchSites(
        status: _filterStatus?.value,
        siteType: SiteType.construction,
        page: _page,
      );
      final filtered = newSites.where((s) => s.userId == userId).toList();
      if (mounted) {
        setState(() {
          _sites.addAll(filtered);
          _hasMore = filtered.length >= 20;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sites: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Text(
          'My Construction Sites',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'filter') _showFilterDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list, size: 18),
                    SizedBox(width: 8),
                    Text('Filter'),
                  ],
                ),
              ),
              if (_filterStatus != null)
                const PopupMenuItem(
                  value: 'clear_filter',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 18),
                      SizedBox(width: 8),
                      Text('Clear Filters'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSites(refresh: true),
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sites.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sites.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _sites.length) {
                        return _loadMoreItem();
                      }
                      final site = _sites[index];
                      return _SiteCard(
                        site: site,
                        onTap: () => context.push(
                          RouteNames.buyerEditSiteWithId(site.id),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.buyerAddSite),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.construction_outlined,
                  size: 60, color: p.iconMuted),
            ),
            const SizedBox(height: 24),
            Text(
              'No construction sites yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first construction site to track materials and progress',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(RouteNames.buyerAddSite),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Site'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadMoreItem() {
    if (!_hasMore) return const SizedBox.shrink();
    Future.delayed(Duration.zero, _loadSites);
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Sites'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<SiteStatus?>(
              initialValue: _filterStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Statuses')),
                ...SiteStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))),
              ],
              onChanged: (v) => setState(() => _filterStatus = v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadSites(refresh: true);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final SiteModel site;
  final VoidCallback onTap;

  const _SiteCard({required this.site, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: site.siteType.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(site.siteType.icon,
                        color: site.siteType.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: p.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          site.siteType.displayName,
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: site.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: p.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      site.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: _InfoChip(
                      icon: Icons.priority_high_outlined,
                      label: site.priorityLevel.displayName.toUpperCase(),
                      color: site.priorityLevel.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (site.sizeSqMeters != null)
                    Flexible(
                      child: _InfoChip(
                        icon: Icons.straighten_outlined,
                        label: '${site.sizeSqMeters!.toStringAsFixed(0)} m²',
                        color: p.textMuted,
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      Formatters.formatDate(site.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: p.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SiteStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}