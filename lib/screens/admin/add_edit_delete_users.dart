import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AddEditDeleteUsersPage extends StatefulWidget {
  const AddEditDeleteUsersPage({super.key});

  @override
  State<AddEditDeleteUsersPage> createState() => _AddEditDeleteUsersPageState();
}

class _AddEditDeleteUsersPageState extends State<AddEditDeleteUsersPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('https://theemaeducation.com/register.php'));
      print('GET Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(data['users'].map((user) => {
                  'id': int.parse(user['id'].toString()),
                  'full_name': user['full_name'],
                  'email': user['email'],
                  'phone': user['phone'],
                  'image': user['image'],
                }));
            _filteredUsers = _users;
            _isLoading = false;
          });
        } else {
          _showSnackBar(data['message'] ?? 'No users found');
          setState(() {
            _users = [];
            _filteredUsers = [];
            _isLoading = false;
          });
        }
      } else {
        _showSnackBar('Failed to fetch users: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Error fetching users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _addUser() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showSnackBar('Full Name, Email, Phone, and Password are required to add a user');
      return;
    }

    if (_users.any((user) => user['email'].toLowerCase() == email.toLowerCase())) {
      _showSnackBar('Email already exists');
      return;
    }

    var request = http.MultipartRequest('POST', Uri.parse('https://theemaeducation.com/register.php'));
    request.fields['full_name'] = name;
    request.fields['email'] = email;
    request.fields['phone'] = phone;
    request.fields['password'] = password;

    if (_selectedImage != null) {
      request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
    }

    try {
      print('POST Request Fields: ${request.fields}');
      final response = await request.send();
      final responseData = await http.Response.fromStream(response);
      print('POST Status: ${response.statusCode}, Body: ${responseData.body}');
      final data = jsonDecode(responseData.body);
      if (response.statusCode == 201 && data['success']) {
        _showSnackBar('User added successfully');
        _clearFields();
        _fetchUsers();
      } else {
        _showSnackBar(data['message'] ?? 'Failed to add user');
      }
    } catch (e) {
      print('POST Error: $e');
      _showSnackBar('Error adding user: $e');
    }
  }

 Future<void> _editUser(int index) async {
  // Check index bounds
  if (index < 0 || index >= _filteredUsers.length) { // Use _filteredUsers
    _showSnackBar('Invalid user index');
    return;
  }
  final user = _filteredUsers[index]; // Use _filteredUsers
  _nameController.text = user['full_name'];
  _emailController.text = user['email'];
  _phoneController.text = user['phone'];
  _passwordController.text = '';
  // Reset the selected image when opening the dialog
  setState(() {
    _selectedImage = null; 
  });

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit User"),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (BuildContext context, StateSet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name")),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
                TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone")),
                TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "New Password (optional)"), obscureText: true),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() { // This setState is for the dialog's content
                        _selectedImage = File(pickedFile.path);
                      });
                    }
                  },
                  child: const Text("Pick New Image"),
                ),
                const SizedBox(height: 10),
                // Display logic for the image
                if (_selectedImage != null)
                  Image.file(_selectedImage!, height: 100, width: 100, fit: BoxFit.cover)
                else if (user['image'] != null && user['image'].isNotEmpty)
                  Image.network('https://theemaeducation.com/${user['image']}', height: 100, width: 100, fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.person, size: 50)),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        TextButton(
          onPressed: () async {
            // --- CORE LOGIC CHANGE IS HERE ---
            // 1. Use POST instead of PUT
            var request = http.MultipartRequest('POST', Uri.parse('https://theemaeducation.com/register.php'));
            
            // 2. Add the "_method" field to "tunnel" the PUT request
            request.fields['_method'] = 'PUT';

            // 3. Add the ID and other fields
            request.fields['id'] = '${user['id']}';
            request.fields['full_name'] = _nameController.text.trim();
            request.fields['email'] = _emailController.text.trim();
            request.fields['phone'] = _phoneController.text.trim();

            final updatedPassword = _passwordController.text;
            if (updatedPassword.isNotEmpty) {
              request.fields['password'] = updatedPassword;
            }

            if (_selectedImage != null) {
              request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
            }

            try {
              print('UPDATE (via POST) Request Fields: ${request.fields}');
              final response = await request.send();
              final responseData = await http.Response.fromStream(response);
              print('UPDATE Status: ${response.statusCode}, Body: ${responseData.body}');
              final data = jsonDecode(responseData.body);

              if (response.statusCode == 200 && data['success']) {
                _showSnackBar('User updated successfully');
                Navigator.pop(context); // Close dialog first
                _clearFields();
                _fetchUsers(); // Then refresh
              } else {
                _showSnackBar(data['message'] ?? 'Failed to update user');
              }
            } catch (e) {
              print('UPDATE Error: $e');
              _showSnackBar('Error updating user: $e');
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

/// Deletes a user by their index in the _filteredUsers list.
Future<void> _deleteUser(int index) async {
  // 1. Basic validation of the index provided.
  if (index < 0 || index >= _filteredUsers.length) {
    _showSnackBar('Invalid action: User index is out of bounds.');
    return;
  }

  // 2. Safely get the user's ID. It might be a String or int from the API.
  final dynamic rawUserId = _filteredUsers[index]['id'];
  int? userId;

  if (rawUserId is int) {
    userId = rawUserId;
  } else if (rawUserId is String) {
    userId = int.tryParse(rawUserId);
  }

  // 3. Validate the parsed user ID.
  if (userId == null || userId <= 0) {
    _showSnackBar('Cannot delete user: Invalid User ID found ($rawUserId).');
    return;
  }

  // 4. Show confirmation dialog
  final bool? confirmDelete = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${_filteredUsers[index]['full_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );

  if (confirmDelete != true) return;

  // 5. Construct the URL with the ID as a query parameter.
  final url = Uri.parse('https://theemaeducation.com/register.php?id=$userId');

  print('Attempting to delete user. Request URL: $url');

  try {
    // 6. Send the DELETE request with timeout
    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    print('DELETE Response Status: ${response.statusCode}');
    print('DELETE Response Body: ${response.body}');

    // 7. Handle the response from the server.
    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            _showSnackBar('User deleted successfully!');
            _fetchUsers(); // Refresh the list
          } else {
            _showSnackBar(data['message'] ?? 'Server returned a failure response.');
          }
        } catch (e) {
          print('JSON decode error: $e');
          _showSnackBar('Server returned invalid response format.');
        }
      } else {
        _showSnackBar('Server returned empty response.');
      }
    } else {
      // Handle non-200 status codes
      String errorMessage = 'Failed to delete user. Status: ${response.statusCode}';
      
      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['message'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.length > 100 
              ? '${response.body.substring(0, 100)}...' 
              : response.body;
        }
      }
      
      _showSnackBar(errorMessage);
    }
  } on SocketException {
    _showSnackBar('Network error: Please check your internet connection.');
  } on HttpException {
    _showSnackBar('HTTP error occurred while trying to delete the user.');
  } on TimeoutException {
    _showSnackBar('Request timeout. Please try again.');
  } on FormatException catch (e) {
    _showSnackBar('Server returned invalid response format: $e');
  } catch (e) {
    print('An unexpected error occurred during delete: $e');
    _showSnackBar('An unexpected error occurred. Please try again.');
  }
}
  void _searchUsers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final name = user['full_name'].toLowerCase();
          final email = user['email'].toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _searchController.clear();
    setState(() {
      _selectedImage = null;
      _filteredUsers = _users;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add/Edit/Delete Users"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: "Search by Name or Email",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchUsers,
                      ),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name (required)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email (required)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone (required)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: "Password (required)",
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text("Pick Image (optional)"),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 10),
                    Image.file(_selectedImage!, height: 100, width: 100, fit: BoxFit.cover),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _addUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Add User"),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: _filteredUsers[index]['image'] != null && _filteredUsers[index]['image'].isNotEmpty
                              ? Image.network(
                                  'https://theemaeducation.com/${_filteredUsers[index]['image']}',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50),
                                )
                              : const Icon(Icons.person, size: 50),
                          title: Text(_filteredUsers[index]['full_name']),
                          subtitle: Text('${_filteredUsers[index]['email']} - ${_filteredUsers[index]['phone']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editUser(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteUser(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

void main() {
  runApp(const MaterialApp(home: AddEditDeleteUsersPage()));
}