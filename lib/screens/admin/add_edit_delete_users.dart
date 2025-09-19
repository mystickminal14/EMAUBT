import 'package:ema_app/view_model/folders/user_management_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/user_data_model.dart';
import 'package:image_picker/image_picker.dart';

class AddEditDeleteUsersPage extends StatefulWidget {
  const AddEditDeleteUsersPage({super.key});

  @override
  State<AddEditDeleteUsersPage> createState() => _AddEditDeleteUsersPageState();
}

class _AddEditDeleteUsersPageState extends State<AddEditDeleteUsersPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<UserManagementViewModel>();
    viewModel.fetchUsers(context);
    _searchController.addListener(() {
      viewModel.searchUsers(_searchController.text);
    });
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              "Processing...",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context, String action, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm $action', style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          '$action user $name?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUser(BuildContext context, Users user, UserManagementViewModel viewModel) async {
    viewModel.setFields(
      name: user.fullName,
      email: user.email,
      phone: user.phone,
      password: '',
      image: null,
    );
    _nameController.text = user.fullName ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
    _passwordController.text = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Edit User",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Consumer<UserManagementViewModel>(
                builder: (context, vm, _) => Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Full Name",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
                        onChanged: (value) => vm.setFields(
                          name: value,
                          email: vm.email,
                          phone: vm.phone,
                          password: vm.password,
                          image: vm.selectedImage,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Invalid email format';
                          return null;
                        },
                        onChanged: (value) => vm.setFields(
                          name: vm.name,
                          email: value,
                          phone: vm.phone,
                          password: vm.password,
                          image: vm.selectedImage,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: "Phone",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Phone is required' : null,
                        onChanged: (value) => vm.setFields(
                          name: vm.name,
                          email: vm.email,
                          phone: value,
                          password: vm.password,
                          image: vm.selectedImage,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: "New Password (optional)",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        obscureText: true,
                        onChanged: (value) => vm.setFields(
                          name: vm.name,
                          email: vm.email,
                          phone: vm.phone,
                          password: value,
                          image: vm.selectedImage,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () async {
                          await vm.pickImage();
                        },
                        child: const Text("Pick New Image"),
                      ),
                      const SizedBox(height: 16),
                      if (vm.selectedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(vm.selectedImage!, height: 120, width: 120, fit: BoxFit.cover),
                        )
                      else if (user.image != null && user.image!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${BaseUrl.baseUrl}${user.image}',
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => const Icon(Icons.person, size: 60),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final confirm = await _showConfirmationDialog(context, 'Edit', user.fullName ?? 'No Name');
                if (confirm == true) {
                  _showLoadingDialog(context);
                  await viewModel.editUser(context, user);
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close loading dialog
                  }
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close edit dialog
                  }
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
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
    final viewModel = context.watch<UserManagementViewModel>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;
    double getFontSize(double mobile, double tablet) => isWide ? tablet : mobile;
    double getPadding(double mobile, double tablet) => isWide ? tablet : mobile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Manage Users",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(getPadding(16, 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Add New User",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: getFontSize(18, 22),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: "Search by Name or Email",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainer,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () => viewModel.searchUsers(_searchController.text),
                            ),
                          ),
                          style: TextStyle(fontSize: getFontSize(14, 16)),
                          onFieldSubmitted: (value) => viewModel.searchUsers(value), // Changed from onSubmitted to onFieldSubmitted
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Full Name (required)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
                          style: TextStyle(fontSize: getFontSize(14, 16)),
                          onChanged: (value) => viewModel.setFields(
                            name: value,
                            email: viewModel.email,
                            phone: viewModel.phone,
                            password: viewModel.password,
                            image: viewModel.selectedImage,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: "Email (required)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Email is required';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Invalid email format';
                            return null;
                          },
                          style: TextStyle(fontSize: getFontSize(14, 16)),
                          onChanged: (value) => viewModel.setFields(
                            name: viewModel.name,
                            email: value,
                            phone: viewModel.phone,
                            password: viewModel.password,
                            image: viewModel.selectedImage,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: "Phone (required)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Phone is required' : null,
                          style: TextStyle(fontSize: getFontSize(14, 16)),
                          onChanged: (value) => viewModel.setFields(
                            name: viewModel.name,
                            email: viewModel.email,
                            phone: value,
                            password: viewModel.password,
                            image: viewModel.selectedImage,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: "Password (required)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          ),
                          obscureText: true,
                          validator: (value) => value == null || value.trim().isEmpty ? 'Password is required' : null,
                          style: TextStyle(fontSize: getFontSize(14, 16)),
                          onChanged: (value) => viewModel.setFields(
                            name: viewModel.name,
                            email: viewModel.email,
                            phone: viewModel.phone,
                            password: value,
                            image: viewModel.selectedImage,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(
                              horizontal: getPadding(16, 24),
                              vertical: getPadding(12, 16),
                            ),
                          ),
                          onPressed: viewModel.isActionLoading
                              ? null
                              : () async {
                            await viewModel.pickImage();
                          },
                          child: Text(
                            "Pick Image (optional)",
                            style: TextStyle(fontSize: getFontSize(14, 16)),
                          ),
                        ),
                        if (viewModel.selectedImage != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              viewModel.selectedImage!,
                              height: getFontSize(100, 120),
                              width: getFontSize(100, 120),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(
                                horizontal: getPadding(16, 24),
                                vertical: getPadding(12, 16),
                              ),
                            ),
                            onPressed: viewModel.isActionLoading
                                ? null
                                : () async {
                              if (_formKey.currentState!.validate()) {
                                final confirm = await _showConfirmationDialog(
                                  context,
                                  'Add',
                                  _nameController.text.isEmpty ? 'this user' : _nameController.text,
                                );
                                if (confirm == true) {
                                  _showLoadingDialog(context);
                                  await viewModel.addUser(context);
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop(); // Close loading dialog
                                  }
                                  _formKey.currentState!.reset();
                                  _nameController.clear();
                                  _emailController.clear();
                                  _phoneController.clear();
                                  _passwordController.clear();
                                }
                              }
                            },
                            child: viewModel.isActionLoading
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary),
                              ),
                            )
                                : Text(
                              "Add User",
                              style: TextStyle(fontSize: getFontSize(14, 16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Users",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: getFontSize(20, 24),
                ),
              ),
              const SizedBox(height: 12),
              viewModel.filteredUsers.isEmpty
                  ? Padding(
                padding: EdgeInsets.symmetric(vertical: getPadding(8, 16)),
                child: Text(
                  'No users found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: getFontSize(14, 16),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: viewModel.filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = viewModel.filteredUsers[index];
                  final imageUrl = user.image != null && user.image!.isNotEmpty
                      ? '${BaseUrl.baseUrl}${user.image}'
                      : null;
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.symmetric(vertical: getPadding(6, 8)),
                    child: ListTile(
                      leading: ClipOval(
                        child: imageUrl != null
                            ? Image.network(
                          imageUrl,
                          width: getFontSize(50, 60),
                          height: getFontSize(50, 60),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            size: getFontSize(50, 60),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                            : Icon(
                          Icons.person,
                          size: getFontSize(50, 60),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        user.fullName ?? 'No Name',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: getFontSize(16, 18),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${user.email ?? 'No Email'} - ${user.phone ?? 'No Phone'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: getFontSize(14, 16),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                            onPressed: viewModel.isActionLoading
                                ? null
                                : () => _editUser(context, user, viewModel),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                            onPressed: viewModel.isActionLoading
                                ? null
                                : () async {
                              final confirm = await _showConfirmationDialog(
                                context,
                                'Delete',
                                user.fullName ?? 'No Name',
                              );
                              if (confirm == true) {
                                _showLoadingDialog(context);
                                await viewModel.deleteUser(context, user);
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop(); // Close loading dialog
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}