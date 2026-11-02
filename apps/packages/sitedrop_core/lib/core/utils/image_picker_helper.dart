// lib/core/utils/image_picker_helper.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/colors.dart';

/// Pick and optionally crop images using [image_picker] + [image_cropper].
class ImagePickerHelper {
  ImagePickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Pick from gallery or camera, then crop to a square (avatars).
  static Future<File?> pickAndCropAvatar({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: 90,
    );
    if (picked == null) return null;

    // Cropper is mobile-only; on web/desktop return original.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return File(picked.path);
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: AppColors.white,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (_) {
      // Cropper plugin missing / misconfigured — still return the pick.
      return File(picked.path);
    }
  }

  static Future<File?> pickFromGallery() =>
      pickAndCropAvatar(source: ImageSource.gallery);

  static Future<File?> pickFromCamera() =>
      pickAndCropAvatar(source: ImageSource.camera);
}
