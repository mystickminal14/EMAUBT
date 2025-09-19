import 'package:ema_app/screens/users/user_folder_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // For TimeoutException

class EPSSectionPage extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;

  const EPSSectionPage({
    super.key,
    required this.userIdentifier,
    required this.isAdmin, required String fullName, required String profileImage, required String userEmail, required folderId, required String folderName,
  });

  @override
  _FreeFilesQuizSets createState() => _FreeFilesQuizSets();
}

class _FreeFilesQuizSets extends State<EPSSectionPage> {
  List<Map<String, dynamic>> folders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFolders();
  }

  Future<void> _fetchFolders() async {
    try {
      final response = await http
          .get(Uri.parse("https://theemaeducation.com/folders.php"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedFolders =
            List<Map<String, dynamic>>.from(json.decode(response.body));
        setState(() {
          folders = fetchedFolders.map((folder) {
            return {
              "id": int.tryParse(folder["id"].toString()) ?? 0,
              "name": folder["name"],
              "icon_path": folder["icon_path"],
            };
          }).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load folders: Server error (${response.statusCode})";
        });
      }
    } on TimeoutException {
      setState(() {
        _isLoading = false;
        _errorMessage = "Request timed out. Please check your connection.";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading folders: $e";
      });
    }
  }

  void _openFolder(int folderId, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFolderDetailsPage(
          folderId: folderId,
          folderName: folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin, userId: '', userName: '', role: '',
        ),
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _openFolder(folder["id"], folder["name"]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder icon
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: folder["icon_path"] != null &&
                        folder["icon_path"].toString().isNotEmpty
                    ? Image.network(
                        "https://theemaeducation.com/${folder["icon_path"]}",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.folder,
                              color: Colors.blue, size: 48);
                        },
                      )
                    : const Icon(Icons.folder,
                        color: Colors.blue, size: 48),
              ),
            ),

            // Folder name
            Expanded(
              child: Text(
                folder["name"] ?? "Unnamed Folder",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                softWrap: true,
                maxLines: 3,
                textAlign: TextAlign.left,
              ),
            ),
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
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            "EPS TOPIK NEW UBT SESSION",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                    SizedBox(height: 16),
                    Text(
                      "Loading folders...",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchFolders,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Retry",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : folders.isEmpty
                    ? const Center(
                        child: Text(
                          "No folders available",
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: folders
                                .map((folder) => _buildFolderCard(folder))
                                .toList(),
                          ),
                        ),
                      ),
      ),
    );
  }
}
