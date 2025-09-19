import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddEditDeleteAdminsPage extends StatefulWidget {
  const AddEditDeleteAdminsPage({super.key});

  @override
  _AddEditDeleteAdminsPage createState() => _AddEditDeleteAdminsPage();
}

class _AddEditDeleteAdminsPage extends State<AddEditDeleteAdminsPage> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  List<dynamic> _users = [];
  List<dynamic> _admins = [];
  List<dynamic> _filteredUsers = [];
  List<dynamic> _filteredAdmins = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchAdmins();
  }

  Future<void> _fetchUsers() async {
    final url = Uri.parse('https://theemaeducation.com/register.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          _showErrorSnackbar('Empty response from server');
          return;
        }
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _users = data['users'];
            _filteredUsers = _users;
          });
        } else {
          _showErrorSnackbar('Failed to fetch users: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (error) {
      _showErrorSnackbar('Error: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAdmins() async {
    final url = Uri.parse('https://theemaeducation.com/give_admin_access.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          _showErrorSnackbar('Empty response from server');
          return;
        }
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _admins = data['admins'];
            _filteredAdmins = _admins;
          });
        } else {
          _showErrorSnackbar('Error fetching admins: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (error) {
      _showErrorSnackbar('Error: $error');
    }
  }

  Future<void> _grantAdminAccess(String userId, String fullName, String email) async {
    setState(() => _isActionLoading = true);
    final url = Uri.parse('https://theemaeducation.com/give_admin_access.php');
    try {
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'full_name': fullName,
          'email': email,
          'action': 'grant',
        },
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode != 200) {
        _showErrorSnackbar('Server error: ${response.statusCode}');
        return;
      }
      if (response.body.isEmpty) {
        _showErrorSnackbar('Empty response from server');
        return;
      }
      final data = json.decode(response.body);
      if (data['success'] == true) {
        _showErrorSnackbar('Admin access granted to ${data['full_name'] ?? fullName}');
        await _fetchAdmins();
        await _fetchUsers();
      } else {
        _showErrorSnackbar('Error: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (error) {
      _showErrorSnackbar('Error: $error');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _removeAdminAccess(String userId, String fullName) async {
    setState(() => _isActionLoading = true);
    final url = Uri.parse('https://theemaeducation.com/give_admin_access.php');
    try {
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'action': 'remove',
        },
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (response.statusCode != 200) {
        _showErrorSnackbar('Server error: ${response.statusCode}');
        return;
      }
      if (response.body.isEmpty) {
        _showErrorSnackbar('Empty response from server');
        return;
      }
      final data = json.decode(response.body);
      if (data['success'] == true) {
        _showErrorSnackbar('Admin access removed from ${data['full_name'] ?? fullName}');
        await _fetchAdmins();
        await _fetchUsers();
      } else {
        _showErrorSnackbar('Error: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (error) {
      _showErrorSnackbar('Error: $error');
    } finally {
      setState(() => _isActionLoading = false);
    }
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width and height for responsive sizing
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;

    double getFontSize(double mobile, double tablet) => isWide ? tablet : mobile;
    double getPadding(double mobile, double tablet) => isWide ? tablet : mobile;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Users"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(getPadding(12, 32)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: "Search by Name or Email",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _searchUsersAndAdmins,
                            ),
                          ),
                          onSubmitted: (_) => _searchUsersAndAdmins(),
                        ),
                        SizedBox(height: getPadding(16, 32)),
                        // Users Section
                        Text(
                          "Users:",
                          style: TextStyle(
                            fontSize: getFontSize(20, 28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _filteredUsers.isEmpty
                            ? Padding(
                                padding: EdgeInsets.symmetric(vertical: getPadding(8, 16)),
                                child: const Text('No users found'),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  final imageUrl = user['image'] != null && user['image'].isNotEmpty
                                      ? 'https://theemaeducation.com/${user['image']}'
                                      : null;
                                  return Card(
                                    margin: EdgeInsets.symmetric(
                                      vertical: getPadding(6, 12),
                                      horizontal: getPadding(0, 0),
                                    ),
                                    child: ListTile(
                                      leading: imageUrl != null
                                          ? ClipOval(
                                              child: Image.network(
                                                imageUrl,
                                                width: getFontSize(40, 60),
                                                height: getFontSize(40, 60),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(Icons.person, size: getFontSize(40, 60));
                                                },
                                              ),
                                            )
                                          : Icon(Icons.person, size: getFontSize(40, 60)),
                                      title: Text(
                                        user['full_name'] ?? 'No Name',
                                        style: TextStyle(fontSize: getFontSize(16, 22)),
                                      ),
                                      subtitle: Text(
                                        user['email'] ?? 'No Email',
                                        style: TextStyle(fontSize: getFontSize(13, 18)),
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: _isActionLoading
                                            ? null
                                            : () => _grantAdminAccess(
                                                  user['id'].toString(),
                                                  user['full_name'],
                                                  user['email'],
                                                ),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: getPadding(12, 24),
                                            vertical: getPadding(8, 14),
                                          ),
                                        ),
                                        child: Text(
                                          "Make Admin",
                                          style: TextStyle(fontSize: getFontSize(13, 18)),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const Divider(),
                        // Admins Section
                        Text(
                          "Admins:",
                          style: TextStyle(
                            fontSize: getFontSize(20, 28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _filteredAdmins.isEmpty
                            ? Padding(
                                padding: EdgeInsets.symmetric(vertical: getPadding(8, 16)),
                                child: const Text('No admins found'),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredAdmins.length,
                                itemBuilder: (context, index) {
                                  final admin = _filteredAdmins[index];
                                  return Card(
                                    margin: EdgeInsets.symmetric(
                                      vertical: getPadding(6, 12),
                                      horizontal: getPadding(0, 0),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.admin_panel_settings,
                                        size: getFontSize(40, 60),
                                      ),
                                      title: Text(
                                        admin['full_name'] ?? 'No Name',
                                        style: TextStyle(fontSize: getFontSize(16, 22)),
                                      ),
                                      subtitle: Text(
                                        admin['email'] ?? 'No Email',
                                        style: TextStyle(fontSize: getFontSize(13, 18)),
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: _isActionLoading
                                            ? null
                                            : () => _removeAdminAccess(
                                                  admin['user_id'].toString(),
                                                  admin['full_name'],
                                                ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: getPadding(12, 24),
                                            vertical: getPadding(8, 14),
                                          ),
                                        ),
                                        child: Text(
                                          "Remove",
                                          style: TextStyle(
                                            fontSize: getFontSize(13, 18),
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        SizedBox(height: getPadding(20, 40)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
