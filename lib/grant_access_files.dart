import 'package:ema_app/view_model/grant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/constants/base_url.dart';

class GrantAccessFilesPage extends StatelessWidget {
  final Map<String, dynamic> entity;
  final bool isAdmin;

  const GrantAccessFilesPage({
    super.key,
    required this.entity,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GrantAccessFilesViewModel()..initializeData(entity['email'] ?? ''),
      child: _GrantAccessFilesPageContent(
        entity: entity,
        isAdmin: isAdmin,
      ),
    );
  }
}

class _GrantAccessFilesPageContent extends StatelessWidget {
  final Map<String, dynamic> entity;
  final bool isAdmin;

  const _GrantAccessFilesPageContent({
    required this.entity,
    required this.isAdmin,
  });

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildItemIcon(dynamic item, IconData defaultIcon) {
    if (item.iconPath != null && item.iconPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          '${BaseUrl.baseUrl}${item.iconPath}',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, size: 40, color: Colors.grey),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      );
    }
    return Icon(defaultIcon, size: 40, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GrantAccessFilesViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Grant File Access'),
            elevation: 0,
          ),
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: () => viewModel.initializeData(entity['email'] ?? ''),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${isAdmin ? 'Admin' : 'User'}: ${entity['full_name'] ?? 'Unknown'}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Email: ${entity['email'] ?? 'No email provided'}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: viewModel.accessTimesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Number of Access Times',
                      hintText: 'Enter the number of times they can access',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  viewModel.files.isEmpty
                      ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No files available'),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.files.length,
                    itemBuilder: (context, index) {
                      final file = viewModel.files[index];
                      return Card(
                        child: CheckboxListTile(
                          value: viewModel.selectedFiles[file.id!] ?? false,
                          onChanged: (bool? value) {
                            viewModel.toggleFileSelection(file.id!, value ?? false);
                          },
                          title: Text(file.name ?? 'Unnamed File'),
                          secondary: _buildItemIcon(file, Icons.insert_drive_file),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  const Text('Quiz Sets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  viewModel.quizSets.isEmpty
                      ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No quiz sets available'),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.quizSets.length,
                    itemBuilder: (context, index) {
                      final quizSet = viewModel.quizSets[index];
                      final isFree = viewModel.isFirstQuizSetInFirstFolder(quizSet);
                      return Card(
                        child: CheckboxListTile(
                          value: viewModel.selectedQuizSets[quizSet.id!] ?? false,
                          onChanged: isFree
                              ? null
                              : (bool? value) {
                            viewModel.toggleQuizSetSelection(quizSet.id!, value ?? false);
                          },
                          title: Text(
                            quizSet.name ?? 'Unnamed Quiz Set',
                            style: TextStyle(
                              color: isFree ? Colors.grey : null,
                            ),
                          ),
                          subtitle: isFree
                              ? const Text(
                            'Free for all (Folder 1, First Quiz)',
                            style: TextStyle(color: Colors.orange),
                          )
                              : null,
                          secondary: _buildItemIcon(quizSet, Icons.quiz),
                          enabled: !isFree,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: viewModel.isLoading
                          ? null
                          : () async {
                        try {
                          final success = await viewModel.grantFileAccess(entity['email'] ?? '', isAdmin);
                          if (success) {
                            _showSuccessSnackBar(context, 'Access granted successfully');
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          _showErrorSnackBar(context, e.toString());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: viewModel.isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.security),
                      label: const Text('Grant Access to Selected Items'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Access Permissions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () async {
                          try {
                            await viewModel.fetchAccessPermissions(entity['email'] ?? '');
                          } catch (e) {
                            _showErrorSnackBar(context, e.toString());
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh permissions',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  viewModel.accessPermissions.isEmpty
                      ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('No access permissions granted yet'),
                        ],
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.accessPermissions.length,
                    itemBuilder: (context, index) {
                      final permission = viewModel.accessPermissions[index];
                      final itemType = permission['item_type'] == 'file' ? 'File' : 'Quiz Set';
                      final itemName = permission['item_name'] ?? 'Unnamed $itemType';
                      final accessTimes = permission['access_times'] == -1
                          ? 'Unlimited'
                          : permission['access_times'].toString();
                      final timesAccessed = permission['times_accessed'].toString();
                      final isDeletable = permission['access_times'] != -1;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: permission['item_type'] == 'file'
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            child: Icon(
                              permission['item_type'] == 'file'
                                  ? Icons.insert_drive_file
                                  : Icons.quiz,
                              color: permission['item_type'] == 'file'
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                          ),
                          title: Text(
                            '$itemType: $itemName',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('Access: $accessTimes'),
                                  const SizedBox(width: 16),

                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('Used: $timesAccessed'),
                                ],
                              )
                            ],
                          ),
                          trailing: isDeletable
                              ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Deletion'),
                                  content: Text('Are you sure you want to remove access to this $itemType?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  final success = await viewModel.deleteAccessPermission(
                                    permission['item_id'],
                                    permission['item_type'],
                                    entity['email'] ?? '',
                                  );
                                  if (success) {
                                    _showSuccessSnackBar(context, 'Access permission removed successfully');
                                  }
                                } catch (e) {
                                  _showErrorSnackBar(context, e.toString());
                                }
                              }
                            },
                            tooltip: 'Remove access',
                          )
                              : Chip(
                            label: const Text('System', style: TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}