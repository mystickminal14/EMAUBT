import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart' as mobile;
import 'package:pdfrx/pdfrx.dart' as desktop;

/// `true` when the mobile-only `flutter_pdfview` renderer is available.
bool get _isMobilePdfPlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Renders a local PDF file on every platform the app ships on.
///
/// `flutter_pdfview` only has an Android/iOS implementation, so Windows (and
/// the other desktop targets plus web) render through `pdfrx`, which is backed
/// by PDFium. Both engines take a plain file path, so callers just hand over
/// the path of the PDF they already cached.
class CrossPlatformPdfView extends StatelessWidget {
  final String filePath;

  /// Called when the underlying renderer fails to open the document.
  final void Function(String error)? onError;

  const CrossPlatformPdfView({
    super.key,
    required this.filePath,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (_isMobilePdfPlatform) {
      return mobile.PDFView(
        filePath: filePath,
        enableSwipe: true,
        autoSpacing: true,
        pageFling: true,
        onError: (e) => onError?.call('$e'),
      );
    }

    return desktop.PdfViewer.file(
      filePath,
      params: desktop.PdfViewerParams(
        loadingBannerBuilder: (context, downloaded, total) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          // Bubble the failure up so the host page can show its own retry UI.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onError?.call('$error'),
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading PDF: $error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
