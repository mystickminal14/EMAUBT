// import 'package:ema_app/admin_folder_detail_page.dart'; // This import might not be needed anymore if FolderDetailPage is replaced everywhere
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Keep kIsWeb for file opening logic
import 'dart:io' show File, Platform;
import 'package:flutter_pdfview/flutter_pdfview.dart';

class FreeFilesQuizLoggedInUsersPage extends StatefulWidget {
  const FreeFilesQuizLoggedInUsersPage({super.key});

  @override
  _FreeFilesQuizLoggedInUsersPageState createState() => _FreeFilesQuizLoggedInUsersPageState();
}

class _FreeFilesQuizLoggedInUsersPageState extends State<FreeFilesQuizLoggedInUsersPage> {
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
      final response = await http.get(Uri.parse("https://theemaeducation.com/folders.php"));
      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedFolders = List<Map<String, dynamic>>.from(json.decode(response.body));
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
          _errorMessage = "Failed to load folders: Server error (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading folders: $e";
      });
    }
  }

  void _openFolder(int folderId, String folderName) {
    // Navigate to FreeForLoginPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FreeForLoginPage( // <--- Still navigating to FreeForLoginPage
           folderId: folderId, // Pass data to the new page
           folderName: folderName, // Pass data to the new page
         ),
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: folder["icon_path"] != null
                ? Image.network(
                    "https://theemaeducation.com/${folder["icon_path"]}",
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.folder, size: 48, color: Colors.blue);
                    },
                  )
                : const Icon(Icons.folder, size: 48, color: Colors.blue),
          ),
        ),
        title: Flexible(
          child: Text(
            folder["name"],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _openFolder(folder["id"], folder["name"]),
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
        title: const Text(
          "Free Files & Quiz for Logged-in Users",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                    SizedBox(height: 16),
                    Text("Loading folders...", style: TextStyle(fontSize: 16, color: Colors.black54)),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchFolders,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Retry", style: TextStyle(color: Colors.white)),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Folders",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              ...folders.map((folder) => _buildFolderCard(folder)),
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }
}

class FreeForLoginPage extends StatefulWidget {
  final int folderId;
  final String folderName;

  const FreeForLoginPage({super.key, required this.folderId, required this.folderName});

  @override
  _FreeForLoginPageState createState() => _FreeForLoginPageState();
}

class _FreeForLoginPageState extends State<FreeForLoginPage> {
  // Lists for all files and quiz sets in the folder
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> quizSets = [];

  // List for items that have been granted access
  List<Map<String, dynamic>> grantedAccessItems = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  // Fetches all content: all files, all quiz sets, and granted access items
  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _fetchFiles(), // Fetches all files in the folder
        _fetchQuizSets(), // Fetches all quiz sets in the folder
        _fetchGrantedAccessItems(), // Fetches items explicitly granted access
      ]);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error fetching content: $e";
      });
    }
  }

  Future<void> _fetchFiles() async {
    try {
      var response = await http.get(Uri.parse(
          'https://theemaeducation.com/folder_details_page.php?action=get_files&folder_id=${widget.folderId}'));
      var decodedResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && decodedResponse['status'] == 'success') {
        setState(() {
          files = List<Map<String, dynamic>>.from(decodedResponse['data'])
              .map((file) => {...file, 'id': int.parse(file['id'].toString())})
              .toList();
        });
      } else {
        print('Failed to fetch files: ${decodedResponse['message']}');
        // Optionally set an error message specific to this fetch if needed
      }
    } catch (e) {
       print('Error fetching files: $e');
    }
  }

  Future<void> _fetchQuizSets() async {
    try {
      var response = await http.get(Uri.parse(
          'https://theemaeducation.com/folder_details_page.php?action=get_quiz_sets&folder_id=${widget.folderId}'));
      var decodedResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && decodedResponse['status'] == 'success') {
        setState(() {
          quizSets = List<Map<String, dynamic>>.from(decodedResponse['data'])
              .map((quizSet) => {...quizSet, 'id': int.parse(quizSet['id'].toString())})
              .toList();
        });
      } else {
        print('Failed to fetch quiz sets: ${decodedResponse['message']}');
      }
    } catch (e) {
       print('Error fetching quiz sets: $e');
    }
  }

  Future<void> _fetchGrantedAccessItems() async {
    try {
       // *** Make sure this URL points to your give_access_to_login_users.php file ***
      var response = await http.get(Uri.parse(
          'https://theemaeducation.com/give_access_to_login_users.php?action=get_granted_access_items&folder_id=${widget.folderId}'));
      var decodedResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && decodedResponse['status'] == 'success') {
        setState(() {
          grantedAccessItems = List<Map<String, dynamic>>.from(decodedResponse['data'])
               // Assuming your backend includes 'item_type' and 'id' for each item
              .map((item) => {
                ...item,
                'id': int.parse(item['id'].toString()),
                'item_type': item['item_type'] // Assuming item_type is returned by the backend
              })
              .toList();
        });
      } else {
        print('Failed to fetch granted access items: ${decodedResponse['message']}');
         // setState(() { // Optionally handle the error message specifically for this fetch
         //   _errorMessage = "Error fetching granted access items: ${decodedResponse['message']}";
         // });
      }
    } catch (e) {
       print('Error fetching granted access items: $e');
       // Optionally set an error message specific to this fetch if needed
    }
  }


  // Function to call the backend to grant access to an item
  Future<void> _giveAccess(String itemType, int itemId) async {
    try {
      var uri = Uri.parse('https://theemaeducation.com/give_access_to_login_users.php?action=give_access');
      var response = await http.post(uri, body: {
        'item_type': itemType,
        'item_id': itemId.toString(),
        // *** IMPORTANT: If access is user-specific, add user_id here ***
        // 'user_id': currentUser.id.toString(), // Example
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      var decodedResponse = jsonDecode(response.body);

      if (decodedResponse['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access granted successfully')),
        );
         // Re-fetch content after granting access to update the lists
         _fetchContent();
      } else {
        throw Exception(decodedResponse['message'] ?? 'Unknown error');
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server timeout. Please try again later.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      String errorMsg = 'Failed to grant access: $e';
      if (e.toString().contains('Failed to fetch')) {
        errorMsg = 'Failed to connect to server. Please check your network or server status.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

   // *** NEW: Function to call the backend to revoke access to an item ***
  Future<void> _revokeAccess(String itemType, int itemId) async {
    try {
      var uri = Uri.parse('https://theemaeducation.com/give_access_to_login_users.php?action=revoke_access');
      var response = await http.post(uri, body: {
        'item_type': itemType,
        'item_id': itemId.toString(),
        // *** IMPORTANT: If access is user-specific, add user_id here ***
        // 'user_id': currentUser.id.toString(), // Example
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      var decodedResponse = jsonDecode(response.body);

      if (decodedResponse['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access revoked successfully')),
        );
         // Re-fetch content after revoking access to update the lists
         _fetchContent();
      } else {
        throw Exception(decodedResponse['message'] ?? 'Unknown error');
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server timeout. Please try again later.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      String errorMsg = 'Failed to revoke access: $e';
      if (e.toString().contains('Failed to fetch')) {
        errorMsg = 'Failed to connect to server. Please check your network or server status.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }


  // Helper to build item icons (remains the same)
  Widget _buildItemIcon(Map<String, dynamic> item, IconData defaultIcon) {
    if (item['icon_path'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          'https://theemaeducation.com/${item['icon_path']}',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, size: 40, color: Colors.grey),
        ),
      );
    }
    return Icon(defaultIcon, size: 40, color: Colors.grey);
  }

 Future<void> _openFile(Map<String, dynamic> file) async {
  final fileUrl = 'https://theemaeducation.com/${file['file_path']}';
  final fileName = file['name'].toString().toLowerCase();
  final isDocument = fileName.endsWith('.pdf') || fileName.endsWith('.docx') || fileName.endsWith('.txt');

  if (isDocument) {
    try {
      // Download the file
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file');
      }

      // Save file temporarily
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file['name']}');
      await tempFile.writeAsBytes(response.bodyBytes);

      if (fileName.endsWith('.pdf')) {
        // Open PDF in-app using flutter_pdfview
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerPage(filePath: tempFile.path, fileName: file['name']),
          ),
        );
      } else if (fileName.endsWith('.txt')) {
        // Handle TXT files by reading and displaying content
        final content = await tempFile.readAsString();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextViewerPage(content: content, fileName: file['name']),
          ),
        );
      } else {
        // Fallback for other document types (e.g., DOCX)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open ${file['name']} in-app, downloading...')),
        );
        await _openFileExternally(tempFile.path, file['name']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening ${file['name']}: $e'), backgroundColor: Colors.redAccent),
      );
    }
  } else {
    // Non-document files (e.g., images, videos) open externally
    await _openFileExternally(fileUrl, file['name']);
  }
}

Future<void> _openFileExternally(String filePath, String fileName) async {
  if (kIsWeb) {
    final uri = Uri.parse(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $fileName'), backgroundColor: Colors.redAccent),
      );
    }
  } else if (Platform.isAndroid || Platform.isIOS) {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $fileName'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $fileName'), backgroundColor: Colors.redAccent),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File opening not supported on this platform'), backgroundColor: Colors.redAccent),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    // Filter the fetched data to separate granted items
    final grantedAccessFiles = grantedAccessItems
        .where((item) => item['item_type'] == 'file')
        .toList();

    final grantedAccessQuizSets = grantedAccessItems
        .where((item) => item['item_type'] == 'quiz_set')
        .toList();


    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchContent,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : (files.isEmpty && quizSets.isEmpty && grantedAccessItems.isEmpty)
                  ? const Center(child: Text("No content available in this folder.", style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Section for All Files ---
                            if (files.isNotEmpty) ...[
                              const Text(
                                "All Files", // Changed title for clarity
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: files.length,
                                itemBuilder: (context, index) {
                                  final file = files[index];
                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      leading: _buildItemIcon(file, Icons.insert_drive_file),
                                      title: Text(file['name']),
                                      onTap: () => _openFile(file), // Tapping opens the file
                                      trailing: IconButton( // Button to grant access
                                        icon: const Icon(Icons.lock_open, color: Colors.green),
                                        onPressed: () => _giveAccess('file', file['id']),
                                        tooltip: 'Give access to login users',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            // --- Section for All Quiz Sets ---
                            if (quizSets.isNotEmpty) ...[
                              const Text(
                                "All Quiz Sets", // Changed title for clarity
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: quizSets.length,
                                itemBuilder: (context, index) {
                                  final quizSet = quizSets[index];
                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      leading: _buildItemIcon(quizSet, Icons.quiz),
                                      title: Text(quizSet['name']),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                           SnackBar(content: Text('Navigate to Quiz Set: ${quizSet['name']}')),
                                        );
                                      },
                                      trailing: IconButton( // Button to grant access
                                        icon: const Icon(Icons.lock_open, color: Colors.green),
                                        onPressed: () => _giveAccess('quiz_set', quizSet['id']),
                                        tooltip: 'Give access to login users',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            // --- Section for Granted Access Files ---
                            if (grantedAccessFiles.isNotEmpty) ...[
                              const Text(
                                "Files (Granted Access)",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: grantedAccessFiles.length,
                                itemBuilder: (context, index) {
                                  final file = grantedAccessFiles[index];
                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      leading: _buildItemIcon(file, Icons.insert_drive_file),
                                      title: Text(file['name']),
                                      onTap: () => _openFile(file), // Tapping opens the file
                                      trailing: IconButton( // Button to revoke access
                                        icon: const Icon(Icons.lock, color: Colors.red), // Use a lock/delete icon
                                        onPressed: () => _revokeAccess('file', file['id']), // Call revoke function
                                        tooltip: 'Revoke access',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                             // --- Section for Granted Access Quiz Sets ---
                            if (grantedAccessQuizSets.isNotEmpty) ...[
                              const Text(
                                "Quiz Sets (Granted Access)",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: grantedAccessQuizSets.length,
                                itemBuilder: (context, index) {
                                  final quizSet = grantedAccessQuizSets[index];
                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      leading: _buildItemIcon(quizSet, Icons.quiz),
                                      title: Text(quizSet['name']),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                           SnackBar(content: Text('Navigate to Quiz Set: ${quizSet['name']}')),
                                        );
                                      },
                                       trailing: IconButton( // Button to revoke access
                                        icon: const Icon(Icons.lock, color: Colors.red), // Use a lock/delete icon
                                        onPressed: () => _revokeAccess('quiz_set', quizSet['id']), // Call revoke function
                                        tooltip: 'Revoke access',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
    );
  }
}
// PDF Viewer Page
class PDFViewerPage extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PDFViewerPage({super.key, required this.filePath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: Colors.green,
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading PDF: $error'), backgroundColor: Colors.redAccent),
          );
        },
      ),
    );
  }
}

// Text Viewer Page
class TextViewerPage extends StatelessWidget {
  final String content;
  final String fileName;

  const TextViewerPage({super.key, required this.content, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          content,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}