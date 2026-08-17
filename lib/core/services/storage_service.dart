//import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:skin_mate/core/services/supabase_service.dart';

class StorageService {

  StorageService._();

  static const String _bucketScanImages    = 'scan-images';
  static const String _bucketProductImages = 'product-images';
  static const String _bucketDiaryImages   = 'diary-images';
  static const String _bucketAvatars       = 'avatars';

  // ── Compression settings ──────────────────────────────
  static const int _maxImageWidth   = 1080; // max width in pixels
  static const int _jpegQuality     = 82;   // 0-100, higher = better quality
  //static const int _maxFileSizeBytes = 1024 * 1024; // 1MB limit

  static Future<String> uploadScanImage({
    required XFile  file,
    required String scanID,
  }) async {
    // Get current user ID — needed for the storage path
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Not logged in. Cannot upload scan image.');
    }

    final rawBytes = await file.readAsBytes();

    final compressed = await _compressImage(rawBytes);

    final path = '$userId/${scanID}_original.jpg';

    await SupabaseService.client.storage
        .from(_bucketScanImages)
        .uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert:      true, 
          ),
        );

    final signedUrl = await SupabaseService.client.storage
        .from(_bucketScanImages)
        .createSignedUrl(path, 3600);

    debugPrint('✅ Scan image uploaded: $signedUrl');
    return signedUrl;
  }


  static Future<String> uploadScanThumbnail({
    required XFile  file,
    required String scanID,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Not logged in. Cannot upload thumbnail.');
    }

    final rawBytes = await file.readAsBytes();

    final thumbnail = await _compressImage(
      rawBytes,
      maxWidth: 300,
      quality:  70,
    );

    final path = '$userId/${scanID}_thumb.jpg';

    await SupabaseService.client.storage
        .from(_bucketScanImages)
        .uploadBinary(
          path,
          thumbnail,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert:      true,
          ),
        );

    final signedUrl = await SupabaseService.client.storage
        .from(_bucketScanImages)
        .createSignedUrl(path, 3600);

    debugPrint('✅ Thumbnail uploaded: $signedUrl');
    return signedUrl;
  }

  static Future<String> uploadProductImage({
    required XFile  file,
    required String productID,
  }) async {
    final rawBytes = await file.readAsBytes();

    final compressed = await _compressImage(rawBytes);

    final path = '$productID.jpg';

    await SupabaseService.client.storage
        .from(_bucketProductImages)
        .uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert:      true, // overwrite if product image updated
          ),
        );

    final publicUrl = SupabaseService.client.storage
        .from(_bucketProductImages)
        .getPublicUrl(path);

    debugPrint('✅ Product image uploaded: $publicUrl');
    return publicUrl;
  }

  static Future<String> uploadDiaryPhoto({
    required XFile  file,
    required String diaryID,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Not logged in. Cannot upload diary photo.');
    }

    final rawBytes = await file.readAsBytes();
    final compressed = await _compressImage(rawBytes);

    final path = '$userId/$diaryID.jpg';

    await SupabaseService.client.storage
        .from(_bucketDiaryImages)
        .uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert:      true,
          ),
        );

    final signedUrl = await SupabaseService.client.storage
        .from(_bucketDiaryImages)
        .createSignedUrl(path, 86400); 

    debugPrint('✅ Diary photo uploaded: $signedUrl');
    return signedUrl;
  }

  static Future<String> uploadAvatar({
    required XFile  file,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Not logged in. Cannot upload avatar.');
    }

    final rawBytes = await file.readAsBytes();

    final compressed = await _compressImage(
      rawBytes,
      maxWidth: 200,
      quality:  85,
    );

    final path = '$userId.jpg';

    await SupabaseService.client.storage
        .from(_bucketAvatars)
        .uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert:      true, 
          ),
        );

    final publicUrl = SupabaseService.client.storage
        .from(_bucketAvatars)
        .getPublicUrl(path);

    final urlWithTimestamp = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    debugPrint('✅ Avatar uploaded: $urlWithTimestamp');
    return urlWithTimestamp;
  }


  static Future<void> deleteImage({
    required String bucket,
    required String path,
  }) async {
    try {
      await SupabaseService.client.storage
          .from(bucket)
          .remove([path]);
      debugPrint('✅ Deleted from $bucket: $path');
    } catch (e) {
      debugPrint('⚠️ Delete failed (non-fatal): $e');
    }
  }

  static Future<String> refreshSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    final signedUrl = await SupabaseService.client.storage
        .from(bucket)
        .createSignedUrl(path, expiresInSeconds);
    return signedUrl;
  }

  static Future<Uint8List> _compressImage(
    Uint8List rawBytes, {
    int maxWidth = _maxImageWidth,
    int quality  = _jpegQuality,
  }) async {
  
    return await compute(_compressInBackground, {
      'bytes':    rawBytes,
      'maxWidth': maxWidth,
      'quality':  quality,
    });
  }


  static Uint8List _compressInBackground(Map<String, dynamic> params) {
    final Uint8List rawBytes = params['bytes']    as Uint8List;
    final int       maxWidth = params['maxWidth'] as int;
    final int       quality  = params['quality']  as int;

    final original = img.decodeImage(rawBytes);

    if (original == null) {

      return rawBytes;
    }


    final resized = original.width > maxWidth
        ? img.copyResize(original, width: maxWidth)
        : original;


    final compressed = img.encodeJpg(resized, quality: quality);

    return Uint8List.fromList(compressed);
  }

  static String fileSizeKB(Uint8List bytes) {
    final kb = (bytes.lengthInBytes / 1024).toStringAsFixed(1);
    return '${kb}KB';
  }
}