// lib/presentation/screens/profile/user/addresses_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../../providers/address_provider.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  Future<void> _deleteAddress(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This address will be removed from your book.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(addressServiceProvider).deleteAddress(id);
      ref.invalidate(addressBookProvider);
      Helpers.showSuccessToast('Address deleted');
    } catch (e) {
      Helpers.showErrorToast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(addressBookProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: appBarTitle(context, 'Addresses'),
        backgroundColor: context.palette.surface,
        elevation: 0,
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await context.push<bool>(RouteNames.addAddress);
          if (saved == true) {
            ref.invalidate(addressBookProvider);
          }
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: bookAsync.when(
        loading: () => const LoadingWidget(message: 'Loading addresses…'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.textMuted),
            ),
          ),
        ),
        data: (book) {
          if (book.addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: context.palette.iconMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No saved addresses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final saved = await context.push<bool>(
                        RouteNames.addAddress,
                      );
                      if (saved == true) {
                        ref.invalidate(addressBookProvider);
                      }
                    },
                    child: Text('Add address'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: book.addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final address = book.addresses[index];
              return Slidable(
                key: ValueKey('address-${address.id}'),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.32,
                  children: [
                    SlidableAction(
                      onPressed: (_) =>
                          _deleteAddress(context, ref, address.id),
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
                child: Card(
                  color: context.palette.surface,
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: address.isDefault
                          ? AppColors.primary
                          : context.palette.iconMuted,
                    ),
                    title: Text(
                      address.displayLabel,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      address.fullAddress,
                      style: TextStyle(color: context.palette.textMuted),
                    ),
                    trailing: address.isDefault
                        ? Chip(
                            label: Text('Default'),
                            backgroundColor: context.palette.primarySoft,
                            labelStyle: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          )
                        : null,
                    onTap: () async {
                      final saved = await context.push<bool>(
                        RouteNames.editAddressWithId(address.id),
                      );
                      if (saved == true) {
                        ref.invalidate(addressBookProvider);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
