
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GrantAccessFilesPage extends StatefulWidget {
  final Map<String, dynamic> entity;
  final bool isAdmin;

  const GrantAccessFilesPage({
    super.key,
    required this.entity,
    required this.isAdmin,
  });

  @override
  State<GrantAccessFilesPage> createState() => _GrantAccessFilesPageState();
}

class _GrantAccessFilesPageState extends State<GrantAccessFilesPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> quizSets = [];
  List<Map<String, dynamic>> accessPermissions = [];
  final TextEditingController _accessTimesController = TextEditingController();
  final Map<int, bool> _selectedFiles = {};
  final Map<int, bool> _selectedQuizSets = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _fetchFiles(),
      _fetchQuizSets(),
      _fetchAccessPermissions(),
    ]);
  }

  Future<void> _fetchFiles() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://theemaeducation.com/folder_details_page.php?action=get_all_files'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Files response status: ${response.statusCode}');
      debugPrint('Files response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          setState(() {
            files = List<Map<String, dynamic>>.from(data['data']).map((file) {
              file['id'] = int.parse(file['id'].toString());
              _selectedFiles[file['id']] = false;
              return file;
            }).toList();
          });
        } else {
          _showErrorSnackBar('Error fetching files: ${data['message']}');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching files: $e');
      _showErrorSnackBar('Failed to fetch files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchQuizSets() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://theemaeducation.com/folder_details_page.php?action=get_all_quiz_sets'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Quiz sets response status: ${response.statusCode}');
      debugPrint('Quiz sets response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          List<Map<String, dynamic>> allQuizSets = List<Map<String, dynamic>>.from(data['data']).map((quizSet) {
            quizSet['id'] = int.parse(quizSet['id'].toString());
            return quizSet;
          }).toList();

          allQuizSets.sort((a, b) => a['id'].compareTo(b['id']));

          setState(() {
            quizSets = allQuizSets;
            for (var quizSet in quizSets) {
              _selectedQuizSets[quizSet['id']] = false;
            }
          });
        } else {
          _showErrorSnackBar('Error fetching quiz sets: ${data['message']}');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching quiz sets: $e');
      _showErrorSnackBar('Failed to fetch quiz sets: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAccessPermissions() async {
    setState(() => _isLoading = true);
    try {
      final email = widget.entity['email'] ?? '';
      if (email.isEmpty) {
        _showErrorSnackBar('No email provided for entity');
        return;
      }

      final uri = Uri.parse('https://theemaeducation.com/grant_file_access.php')
          .replace(queryParameters: {
        'action': 'get_access_permissions',
        'identifier': email,
      });

      debugPrint('Fetching permissions from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Permissions response status: ${response.statusCode}');
      debugPrint('Permissions response headers: ${response.headers}');
      debugPrint('Permissions response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        try {
          final data = jsonDecode(response.body);
          if (data['status'] == "success") {
            setState(() {
              accessPermissions = List<Map<String, dynamic>>.from(data['data'] ?? []);
            });
          } else {
            _showErrorSnackBar('Error fetching access permissions: ${data['message']}');
          }
        } catch (jsonError) {
          debugPrint('JSON decode error: $jsonError');
          debugPrint('Response body was: ${response.body}');
          _showErrorSnackBar('Invalid response format from server');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching access permissions: $e');
      _showErrorSnackBar('Failed to fetch access permissions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _grantFileAccess(String identifier) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final accessTimes = int.tryParse(_accessTimesController.text) ?? 0;

    if (accessTimes <= 0) {
      _showErrorSnackBar('Please enter a valid number of access times');
      setState(() => _isLoading = false);
      return;
    }

    List<Map<String, dynamic>> selectedItems = [];
    for (var file in files) {
      if (_selectedFiles[file['id']] == true) {
        selectedItems.add({'item_id': file['id'], 'item_type': 'file'});
      }
    }
    for (var quizSet in quizSets) {
      if (_selectedQuizSets[quizSet['id']] == true) {
        if (quizSet['folder_id'] == 1 && quizSets.isNotEmpty && quizSet['id'] == quizSets[0]['id']) {
          continue;
        }
        selectedItems.add({'item_id': quizSet['id'], 'item_type': 'quiz_set'});
      }
    }

    if (selectedItems.isEmpty) {
      _showErrorSnackBar('Please select at least one file or quiz set');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://theemaeducation.com/grant_file_access.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'identifier': identifier,
          'is_admin': widget.isAdmin.toString(),
          'items': jsonEncode(selectedItems),
          'access_times': accessTimes.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Grant access response status: ${response.statusCode}');
      debugPrint('Grant access response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccessSnackBar(data['message']);
          _fetchAccessPermissions(); // Refresh permissions
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          _showErrorSnackBar('Error: ${data['message']}');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error granting access: $e');
      _showErrorSnackBar('Error granting access: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccessPermission(int itemId, String itemType, String identifier) async {
    if (_isLoading) return;
    
    // Show confirmation dialog
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://theemaeducation.com/grant_file_access.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'action': 'delete_access_permission',
          'identifier': identifier,
          'item_id': itemId.toString(),
          'item_type': itemType,
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Delete response status: ${response.statusCode}');
      debugPrint('Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccessSnackBar(data['message']);
          _fetchAccessPermissions(); // Refresh the list after deletion
        } else {
          _showErrorSnackBar('Error: ${data['message']}');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting access permission: $e');
      _showErrorSnackBar('Failed to delete access permission: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildItemIcon(Map<String, dynamic> item, IconData defaultIcon) {
    if (item['icon_path'] != null && item['icon_path'].isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          'https://theemaeducation.com/${item['icon_path']}',
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

  bool _isFirstQuizSetInFirstFolder(Map<String, dynamic> quizSet) {
    return quizSet['folder_id'] == 1 && quizSets.isNotEmpty && quizSet['id'] == quizSets[0]['id'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grant File Access'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initializeData,
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
                              '${widget.isAdmin ? 'Admin' : 'User'}: ${widget.entity['full_name'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Email: ${widget.entity['email'] ?? 'No email provided'}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _accessTimesController,
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
                    files.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No files available'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: files.length,
                            itemBuilder: (context, index) {
                              final file = files[index];
                              return Card(
                                child: CheckboxListTile(
                                  value: _selectedFiles[file['id']] ?? false,
                                  onChanged: (bool? value) {
                                    setState(() => _selectedFiles[file['id']] = value ?? false);
                                  },
                                  title: Text(file['name'] ?? 'Unnamed File'),
                                  secondary: _buildItemIcon(file, Icons.insert_drive_file),
                                ),
                              );
                            },
                          ),
                    const Divider(),
                    const Text('Quiz Sets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    quizSets.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No quiz sets available'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: quizSets.length,
                            itemBuilder: (context, index) {
                              final quizSet = quizSets[index];
                              final isFree = _isFirstQuizSetInFirstFolder(quizSet);
                              return Card(
                                child: CheckboxListTile(
                                  value: _selectedQuizSets[quizSet['id']] ?? false,
                                  onChanged: isFree
                                      ? null
                                      : (bool? value) {
                                          setState(() => _selectedQuizSets[quizSet['id']] = value ?? false);
                                        },
                                  title: Text(
                                    quizSet['name'] ?? 'Unnamed Quiz Set',
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
                        onPressed: _isLoading
                            ? null
                            : () => _grantFileAccess(widget.entity['email'] ?? ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isLoading
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
                          onPressed: _fetchAccessPermissions,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh permissions',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    accessPermissions.isEmpty
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
                            itemCount: accessPermissions.length,
                            itemBuilder: (context, index) {
                              final permission = accessPermissions[index];
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
                                          Icon(Icons.bar_chart, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text('Used: $timesAccessed'),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: isDeletable
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteAccessPermission(
                                            permission['item_id'],
                                            permission['item_type'],
                                            widget.entity['email'] ?? '',
                                          ),
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
  }

  @override
  void dispose() {
    _accessTimesController.dispose();
    super.dispose();
  }
}