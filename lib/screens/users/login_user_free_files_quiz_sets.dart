import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/screens/users/user_quiz_sets.dart';
import 'package:ema_app/view_model/folders/folder_view_model.dart';
import 'package:ema_app/view_model/folders/free_files_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginUserFreeFilesQuizSets extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;

  const LoginUserFreeFilesQuizSets({
    super.key,
    required this.userIdentifier,
    required this.isAdmin,
  });

  @override
  _LoginUserFreeFilesQuizSetsState createState() =>
      _LoginUserFreeFilesQuizSetsState();
}

class _LoginUserFreeFilesQuizSetsState
    extends State<LoginUserFreeFilesQuizSets> {
  late SharedPreferences _prefs;
  String? _cachedFullName;
  String? _cachedUserEmail;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<FolderViewModel>(context, listen: false).fetchFolders();
      }
    });
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _cachedFullName = _prefs.getString('fullName') ?? '';
      _cachedUserEmail = _prefs.getString('userEmail') ?? widget.userIdentifier;
    });
  }

  void _openFolder(String folderId, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FreeForLoginPage(
          folderId: folderId,
          folderName: folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          fullName: _cachedFullName,
          userEmail: _cachedUserEmail,
        ),
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: "${BaseUrl.baseUrl}/${folder["icon_path"] ?? ''}",
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox(
              width: 48,
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) =>
            const Icon(Icons.folder, size: 48, color: Colors.teal),
          ),
        ),
        title: Text(
          folder["name"],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        trailing:
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _openFolder(folder["id"], folder["name"]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Free Files & Quiz Sets"),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: Consumer<FolderViewModel>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.folders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_off, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "No folders available",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchFolders(),
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.folders.length,
              itemBuilder: (context, index) {
                final folder = provider.folders[index];
                return _buildFolderCard(folder.toJson());
              },
            );
          },
        ),
      ),
    );
  }
}
class FreeForLoginPage extends StatelessWidget {
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const FreeForLoginPage({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FreeAccessViewModel()..fetchGrantedAccessItems(folderId),
      child: Scaffold(
        appBar: AppBar(
          title: Text(folderName),
          backgroundColor: Colors.teal,
          centerTitle: true,
          elevation: 2,
        ),
        body: SafeArea(
          child: Consumer<FreeAccessViewModel>(
            builder: (context, vm, child) {
              if (vm.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (vm.errorMessage != null) {
                return Center(child: Text(vm.errorMessage!));
              }

              if (vm.files.isEmpty && vm.quizSets.isEmpty) {
                return const Center(child: Text("No content available"));
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (vm.files.isNotEmpty) ...[
                    const Text("Files",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...vm.files.map((file) => _buildItemTile(context, file, 'file')),
                    const SizedBox(height: 20),
                  ],
                  if (vm.quizSets.isNotEmpty) ...[
                    const Text("Quiz Sets",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...vm.quizSets.map((quizSet) =>
                        _buildItemTile(context, quizSet, 'quiz_set')),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, Map<String, dynamic> item, String itemType) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: '${BaseUrl.baseUrl}/${item['icon_path'] ?? ''}',
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Icon(
              itemType == 'file' ? Icons.insert_drive_file : Icons.quiz,
              size: 40,
              color: Colors.grey,
            ),
          ),
        ),
        title: Text(
          item['name'] ?? (itemType == 'file' ? 'Unnamed File' : 'Unnamed Quiz Set'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text("Can Use", style: TextStyle(color: Colors.green)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (itemType == 'quiz_set') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserQuizSetsPage(
                  quizSetId: item['id'],
                  quizSetName: item['name'],
                  userId: isAdmin
                      ? ''
                      : userIdentifier.isEmpty
                      ? 'guest'
                      : userIdentifier,
                  userName: fullName ?? '',
                  userEmail: isAdmin ? userIdentifier : (userEmail ?? userIdentifier),
                  role: isAdmin ? 'admin' : 'user',
                  folderId: folderId,
                  folderName: folderName,
                  isAdmin: isAdmin,
                  userIdentifier: userIdentifier,
                  preStart: true,
                  cachedFiles: {},
                  quizData: {},
                ),
              ),
            ).then((_) {
              // refresh on return
              Provider.of<FreeAccessViewModel>(context, listen: false)
                  .fetchGrantedAccessItems(folderId);
            });
          } else {
            // TODO: implement file open
          }
        },
      ),
    );
  }
}
