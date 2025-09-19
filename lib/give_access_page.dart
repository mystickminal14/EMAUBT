import 'package:flutter/material.dart';
import 'package:http/http.dart' as http show get, post;
import 'dart:convert';
import 'grant_access_files.dart';

class GiveAccessPage extends StatefulWidget {
  const GiveAccessPage({super.key});

  @override
  State<GiveAccessPage> createState() => _GiveAccessPageState();
}

class _GiveAccessPageState extends State<GiveAccessPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _filteredAdmins = [];
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _quizSets = [];
  List<Map<String, dynamic>> _grantedItems = [];
  List<Map<String, dynamic>> _activatedItems = [];
  final List<int> _selectedItems = []; // Track selected items for mass deletion

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchUsersAndAdmins(),
        _fetchFiles(),
        _fetchQuizSets(),
        _fetchGrantedItems(),
        _fetchActivatedItems(),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsersAndAdmins() async {
    try {
      final usersResponse = await http.get(Uri.parse('https://theemaeducation.com/register.php'));
      final adminsResponse = await http.get(Uri.parse('https://theemaeducation.com/get_admins.php'));

      if (usersResponse.statusCode == 200) {
        final usersData = json.decode(usersResponse.body);
        if (usersData['success'] == true) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(usersData['users']);
            _filteredUsers = _users;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching users: ${usersData['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server error while fetching users')),
        );
      }

      if (adminsResponse.statusCode == 200) {
        final adminsData = json.decode(adminsResponse.body);
        if (adminsData['success'] == true) {
          setState(() {
            _admins = List<Map<String, dynamic>>.from(adminsData['admins']);
            _filteredAdmins = _admins;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching admins: ${adminsData['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server error while fetching admins')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching users/admins: $e');
    }
  }

  Future<void> _fetchFiles() async {
    try {
      final response = await http.get(
        Uri.parse('https://theemaeducation.com/folder_details_page.php?action=get_all_files'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          setState(() {
            _files = List<Map<String, dynamic>>.from(data['data']).map((file) {
              file['id'] = int.parse(file['id'].toString());
              file['is_activated'] = file['is_activated'] ?? false;
              return file;
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching files: $e');
    }
  }

  Future<void> _fetchQuizSets() async {
    try {
      final response = await http.get(
        Uri.parse('https://theemaeducation.com/folder_details_page.php?action=get_all_quiz_sets'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          setState(() {
            _quizSets = List<Map<String, dynamic>>.from(data['data']).map((quizSet) {
              quizSet['id'] = int.parse(quizSet['id'].toString());
              quizSet['is_activated'] = quizSet['is_activated'] ?? false;
              return quizSet;
            }).toList()
              ..sort((a, b) => a['id'].compareTo(b['id']));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching quiz sets: $e');
    }
  }

  Future<void> _fetchGrantedItems() async {
    try {
      final response = await http.get(
        Uri.parse('https://theemaeducation.com/grant_file_access.php?action=get_all_permissions'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          setState(() {
            _grantedItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching granted items: $e');
    }
  }

  Future<void> _fetchActivatedItems() async {
    try {
      final response = await http.get(
        Uri.parse('https://theemaeducation.com/grant_file_access.php?action=get_all_activations'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          setState(() {
            _activatedItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching activated items: $e');
    }
  }

  Future<void> _deleteActivatedItem(int itemId, String itemType) async {
    try {
      final response = await http.post(
        Uri.parse('https://theemaeducation.com/grant_file_access.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': 'delete_activation',
          'item_type': itemType,
          'item_id': itemId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _activatedItems.removeWhere((item) => item['item_id'] == itemId && item['item_type'] == itemType);
            if (itemType == 'file') {
              _files = _files.map((file) {
                if (file['id'] == itemId) {
                  file['is_activated'] = false;
                }
                return file;
              }).toList();
            } else {
              _quizSets = _quizSets.map((quizSet) {
                if (quizSet['id'] == itemId) {
                  quizSet['is_activated'] = false;
                }
                return quizSet;
              }).toList();
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$itemType deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message'] ?? 'Failed to delete item'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error (${response.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

Future<void> _deleteSelectedItems() async {
  if (_selectedItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No items selected for deletion')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm Mass Deletion'),
      content: Text('Are you sure you want to delete ${_selectedItems.length} selected items?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text('Deleting selected items...'),
                  ],
                ),
              ),
            );

            try {
              // Log selected items for debugging
              debugPrint('Selected items for deletion: $_selectedItems');
              final itemsToDelete = _activatedItems
                  .where((item) => _selectedItems.contains(item['item_id']))
                  .map((item) => {
                        'item_id': item['item_id'],
                        'item_type': item['item_type'],
                      })
                  .toList();

              // Log payload for debugging
              debugPrint('Items to delete payload: ${jsonEncode(itemsToDelete)}');
              if (itemsToDelete.isEmpty) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No valid items to delete'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final response = await http.post(
                Uri.parse('https://theemaeducation.com/grant_file_access.php'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'action': 'batch_delete',
                  'items': itemsToDelete,
                }),
              ).timeout(const Duration(seconds: 10));

              if (!mounted) return;
              Navigator.pop(context);

              if (response.statusCode == 200 && response.body.isNotEmpty) {
                final data = jsonDecode(response.body);
                debugPrint('Response: ${response.body}');
                if (data['success'] == true) {
                  setState(() {
                    _activatedItems.removeWhere(
                        (item) => _selectedItems.contains(item['item_id']));
                    for (var item in itemsToDelete) {
                      if (item['item_type'] == 'file') {
                        _files = _files.map((file) {
                          if (file['id'] == item['item_id']) {
                            file['is_activated'] = false;
                          }
                          return file;
                        }).toList();
                      } else {
                        _quizSets = _quizSets.map((quizSet) {
                          if (quizSet['id'] == item['item_id']) {
                            quizSet['is_activated'] = false;
                          }
                          return quizSet;
                        }).toList();
                      }
                    }
                    _selectedItems.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully deleted ${data['success_count'] ?? itemsToDelete.length} items'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${data['message'] ?? 'Failed to delete items'}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Server error (${response.statusCode}): ${response.body}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              Navigator.pop(context);
              debugPrint('Error during deletion: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Network error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

  Future<void> _toggleFileActivation(int fileId, bool currentStatus) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating file activation...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('https://theemaeducation.com/grant_file_access.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': 'update_activation',
          'item_type': 'file',
          'item_id': fileId,
          'is_activated': !currentStatus,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _files = _files.map((file) {
              if (file['id'] == fileId) {
                file['is_activated'] = !currentStatus;
              }
              return file;
            }).toList();
          });
          _fetchActivatedItems();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message'] ?? 'Unknown error occurred'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error (${response.statusCode}): ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling file activation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleQuizSetActivation(int quizSetId, bool currentStatus) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating quiz set activation...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('https://theemaeducation.com/grant_file_access.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'action': 'update_activation',
          'item_type': 'quiz_set',
          'item_id': quizSetId,
          'is_activated': !currentStatus,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _quizSets = _quizSets.map((quizSet) {
              if (quizSet['id'] == quizSetId) {
                quizSet['is_activated'] = !currentStatus;
              }
              return quizSet;
            }).toList();
          });
          _fetchActivatedItems();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quiz set ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message'] ?? 'Unknown error occurred'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error (${response.statusCode}): ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling quiz set activation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

Future<void> _activateAll() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text("Activating all items..."),
        ],
      ),
    ),
  );

  try {
    final itemsToActivate = [
      ..._files.map((file) => {'item_id': file['id'], 'item_type': 'file'}),
      ..._quizSets
          .where((quizSet) =>
              !(quizSet['folder_id'] == 1 &&
                  _quizSets.isNotEmpty &&
                  quizSet['id'] == _quizSets.first['id']))
          .map((quizSet) => {'item_id': quizSet['id'], 'item_type': 'quiz_set'}),
    ];

    final response = await http.post(
      Uri.parse('https://theemaeducation.com/grant_file_access.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'action': 'batch_activate',
        'items': itemsToActivate,
        'is_activated': true,
      }),
    ).timeout(const Duration(seconds: 15)); // Reduced timeout

    Navigator.of(context).pop();

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final successCount = data['success_count'] ?? 0;
        final totalItems = data['total_items'] ?? itemsToActivate.length;
        setState(() {
          _files = _files.map((file) {
            file['is_activated'] = true;
            return file;
          }).toList();
          _quizSets = _quizSets.map((quizSet) {
            final isFreeQuiz = quizSet['folder_id'] == 1 &&
                _quizSets.isNotEmpty &&
                quizSet['id'] == _quizSets.first['id'];
            if (!isFreeQuiz) {
              quizSet['is_activated'] = true;
            }
            return quizSet;
          }).toList();
        });
        await _fetchActivatedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully activated $successCount out of $totalItems items'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        if (data['errors'] != null && (data['errors'] as List).isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Some errors occurred: ${data['errors'].take(2).join(', ')}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${data['message'] ?? 'Failed to activate items'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server error (${response.statusCode}): ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Network error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Users and Admins'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search by Name or Email',
                            hintText: 'Enter name or email to search',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: _searchUsersAndAdmins,
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                  ),
                              ],
                            ),
                          ),
                          onSubmitted: (_) => _searchUsersAndAdmins(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Users and Admins',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildUserAdminList(),
                    const SizedBox(height: 20),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Files',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _activateAll,
                          icon: const Icon(Icons.power),
                          label: const Text('Activate All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _files.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No files available'),
                            ),
                          )
                        : Column(
                            children: _files.map((file) {
                              final isActivated = file['is_activated'] ?? false;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                                  title: Text(file['name'] ?? 'Unnamed File'),
                                  subtitle: Text('ID: ${file['id']}'),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.power,
                                      color: isActivated ? Colors.green : Colors.grey,
                                    ),
                                    onPressed: () => _toggleFileActivation(file['id'], isActivated),
                                    tooltip: isActivated ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 16),
                    const Text(
                      'Quiz Sets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _quizSets.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No quiz sets available'),
                            ),
                          )
                        : Column(
                            children: _quizSets.map((quizSet) {
                              final isFree = quizSet['folder_id'] == 1 &&
                                  _quizSets.isNotEmpty &&
                                  quizSet['id'] == _quizSets.first['id'];
                              final isActivated = quizSet['is_activated'] ?? false;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.quiz, color: Colors.green),
                                  title: Text(
                                    quizSet['name'] ?? 'Unnamed Quiz Set',
                                    style: TextStyle(
                                      color: isFree ? Colors.grey : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ID: ${quizSet['id']}'),
                                      if (isFree)
                                        const Text(
                                          'Free for all (Folder 1, First Quiz)',
                                          style: TextStyle(color: Colors.orange),
                                        ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.power,
                                      color: isActivated ? Colors.green : Colors.grey,
                                    ),
                                    onPressed: isFree
                                        ? null
                                        : () => _toggleQuizSetActivation(quizSet['id'], isActivated),
                                    tooltip: isActivated ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 16),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Activated Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (_selectedItems.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _deleteSelectedItems,
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete Selected'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActivatedItems(),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Granted Files and Quiz Sets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _grantedItems.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No items granted yet'),
                            ),
                          )
                        : Column(
                            children: _grantedItems.map((permission) {
                              final itemType = permission['item_type'] == 'file' ? 'File' : 'Quiz Set';
                              final itemName = permission['item_name'] ?? 'Unnamed $itemType';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    permission['item_type'] == 'file'
                                        ? Icons.insert_drive_file
                                        : Icons.quiz,
                                    color: permission['item_type'] == 'file' ? Colors.blue : Colors.green,
                                  ),
                                  title: Text('$itemType: $itemName'),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserAdminList() {
    if (_filteredUsers.isEmpty && _filteredAdmins.isEmpty) {
      return const Center(
        child: Text(
          'No users or admins found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_filteredAdmins.isNotEmpty) ...[
          const Text(
            'Admins:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ..._filteredAdmins.map((admin) {
            final matchingUsers = _filteredUsers.where((user) =>
                user['email'] == admin['email'] || user['full_name'] == admin['full_name']);

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GrantAccessFilesPage(
                                    entity: admin,
                                    isAdmin: true,
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  _fetchGrantedItems();
                                }
                              });
                            },
                            child: Text(
                              'Admin: ${admin['full_name']} (${admin['email']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (matchingUsers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Matching Users:',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...matchingUsers.map((user) => Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GrantAccessFilesPage(
                                      entity: user,
                                      isAdmin: false,
                                    ),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchGrantedItems();
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.grey, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '- ${user['full_name']} (${user['email']})',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (_filteredUsers.where((user) => !_filteredAdmins.any((admin) =>
                admin['email'] == user['email'] || admin['full_name'] == user['full_name'])).isNotEmpty) ...[
          const Text(
            'Users:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ..._filteredUsers.where((user) => !_filteredAdmins.any((admin) =>
              admin['email'] == user['email'] || admin['full_name'] == user['full_name'])).map((user) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GrantAccessFilesPage(
                                entity: user,
                                isAdmin: false,
                              ),
                            ),
                          ).then((result) {
                            if (result == true) {
                              _fetchGrantedItems();
                            }
                          });
                        },
                        child: Text(
                          'User: ${user['full_name']} (${user['email']})',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildActivatedItems() {
    if (_activatedItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No items activated'),
        ),
      );
    }

    return Column(
      children: _activatedItems.map((item) {
        final isSelected = _selectedItems.contains(item['item_id']);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedItems.add(item['item_id']);
                  } else {
                    _selectedItems.remove(item['item_id']);
                  }
                });
              },
            ),
            title: Text(
                '${item['item_type'] == 'file' ? 'File' : 'Quiz Set'}: ${item['item_name'] ?? 'Unnamed ${item['item_type'] == 'file' ? 'File' : 'Quiz Set'}'}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteActivatedItem(item['item_id'], item['item_type']),
              tooltip: 'Delete',
            ),
          ),
        );
      }).toList(),
    );
  }

  void _searchUsersAndAdmins() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
        _filteredAdmins = _admins;
      } else {
        _filteredUsers = _users.where((user) {
          final name = (user['full_name'] ?? '').toLowerCase();
          final email = (user['email'] ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();

        _filteredAdmins = _admins.where((admin) {
          final name = (admin['full_name'] ?? '').toLowerCase();
          final email = (admin['email'] ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _filteredUsers = _users;
      _filteredAdmins = _admins;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}