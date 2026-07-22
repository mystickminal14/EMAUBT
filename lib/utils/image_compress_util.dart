import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// flutter_image_compress has no Windows/Linux implementation, so calling it
/// there throws a MissingPluginException. These wrappers detect that and fall
/// back to the original, uncompressed bytes/file instead of failing the pick.
class ImageCompressUtil {
  static bool get isSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static Future<Uint8List?> compressFile(
    String path, {
    required int quality,
    required int minWidth,
    required int minHeight,
  }) async {
    if (!isSupported) return File(path).readAsBytes();
    return FlutterImageCompress.compressWithFile(
      path,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
    );
  }

  static Future<Uint8List?> compressBytes(
    Uint8List bytes, {
    required int quality,
    required int minWidth,
    required int minHeight,
  }) async {
    if (!isSupported) return bytes;
    return FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
    );
  }

  static Future<XFile> compressFileToFile(
    File file,
    String targetPath, {
    required int quality,
    required int minWidth,
    required int minHeight,
  }) async {
    if (!isSupported) return XFile(file.path);
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );
      return result ?? XFile(file.path);
    } catch (_) {
      return XFile(file.path);
    }
  }
}
