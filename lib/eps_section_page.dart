import 'package:ema_app/constants/base_url.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'model/folder_model.dart';

class EPSSectionPage extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;

  const EPSSectionPage({
    super.key,
    required this.userIdentifier,
    required this.isAdmin,
    required String fullName,
    required String profileImage,
    required String userEmail,
    required folderId,
    required String folderName,
  });

  @override
  _EPSSectionPageState createState() => _EPSSectionPageState();
}

class _EPSSectionPageState extends State<EPSSectionPage> {
  @override
  void initState() {
    super.initState();
    // Fetch folders after first frame
    var log=Logger();
    log.d("jh ${widget.userIdentifier}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (mounted) {
      //   Provider.of<FolderViewModel>(context, listen: false).fetchFolders();
      // }
    });
  }

  void _openFolder(String folderId, String folderName) {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => UserFolderDetailsPage(
    //       folderId: folderId,
    //       folderName: folderName,
    //       userIdentifier: widget.userIdentifier,
    //       isAdmin: widget.isAdmin,
    //       userId: '',
    //       userName: '',
    //       role: '',
    //     ),
    //   ),
    // );
  }

  Widget _buildFolderCard(FolderModel folder) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () => _openFolder(folder.id ?? '', folder.name ?? ''),
        child: Row(
          children: [
            // Folder icon / image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (folder.iconPath != null && folder.iconPath!.isNotEmpty)
                  ? Image.network(
                "${BaseUrl.baseUrl}${folder.iconPath}",
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.folder,
                      color: Colors.blue, size: 40);
                },
              )
                  : const Icon(Icons.folder, color: Colors.blue, size: 40),
            ),

            const SizedBox(width: 12),

            // Folder name
            Expanded(
              child: Text(
                folder.name ?? "Unnamed Folder",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Chevron >
            const Icon(Icons.chevron_right, color: Colors.grey, size: 28),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.blue[700],
        centerTitle: true,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "EPS TOPIK NEW UBT SESSION",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      // body: SafeArea(
      //   child: Consumer<FolderViewModel>(
      //     builder: (context, folderVM, _) {
      //       if (folderVM.isLoading && folderVM.folders.isEmpty) {
      //         return const Center(
      //           child: Column(
      //             mainAxisAlignment: MainAxisAlignment.center,
      //             children: [
      //               CircularProgressIndicator(
      //                   valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
      //               SizedBox(height: 16),
      //               Text(
      //                 "Loading folders...",
      //                 style: TextStyle(fontSize: 16, color: Colors.black54),
      //               ),
      //             ],
      //           ),
      //         );
      //       }
      //
      //       if (folderVM.folders.isEmpty) {
      //         return const Center(
      //           child: Text(
      //             "No folders available",
      //             style: TextStyle(fontSize: 18, color: Colors.black54),
      //           ),
      //         );
      //       }
      //
      //       return SingleChildScrollView(
      //         child: Padding(
      //           padding: const EdgeInsets.all(16.0),
      //           child: Column(
      //             children: folderVM.folders
      //                 .map((folder) => _buildFolderCard(folder))
      //                 .toList(),
      //           ),
      //         ),
      //       );
      //     },
      //   ),
      // ),
    );
  }
}