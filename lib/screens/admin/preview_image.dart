import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// flutter_pdfview only supports Android/iOS, so desktop falls back to
// opening the PDF with the OS's default viewer via open_file.
bool get _supportsInAppPdfView =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class PDFPreviewPage extends StatefulWidget {
  final String url;
  const PDFPreviewPage({super.key, required this.url});

  @override
  State<PDFPreviewPage> createState() => _PDFPreviewPageState();
}

class _PDFPreviewPageState extends State<PDFPreviewPage> {
  String? localPath;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/temp.pdf';
    await Dio().download(widget.url, filePath);
    if (!mounted) return;
    setState(() {
      localPath = filePath;
    });
    if (!_supportsInAppPdfView) {
      OpenFile.open(filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (localPath == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_supportsInAppPdfView) {
      return Scaffold(
        appBar: AppBar(title: const Text("PDF Preview")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Opened in your default PDF viewer."),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => OpenFile.open(localPath!),
                child: const Text("Open again"),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Preview")),
      body: PDFView(filePath: localPath!),
    );
  }
}
