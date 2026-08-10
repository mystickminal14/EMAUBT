import 'package:ema_app/screens/viewer/cross_platform_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    if (localPath == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Preview")),
      body: CrossPlatformPdfView(filePath: localPath!),
    );
  }
}
