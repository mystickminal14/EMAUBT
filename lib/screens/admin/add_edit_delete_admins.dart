import 'package:ema_app/view_model/folders/admin_management_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart'; // Added for debugging

class AddEditDeleteAdminsPage extends StatefulWidget {
  const AddEditDeleteAdminsPage({super.key});

  @override
  _AddEditDeleteAdminsPageState createState() => _AddEditDeleteAdminsPageState();
}

class _AddEditDeleteAdminsPageState extends State<AddEditDeleteAdminsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Logger _logger = Logger(); // Added for debugging

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<AdminManagementViewModel>();
    viewModel.fetchUsers(context);
    viewModel.fetchAdmins(context);
    _searchController.addListener(() {
      viewModel.searchUsersAndAdmins(_searchController.text);
    });
  }

  void _showLoadingDialog(BuildContext context, Future<void> operation) async {
    _logger.i('Showing loading dialog'); // Debug log
    final dialogFuture = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Processing..."),
          ],
        ),
      ),
    );

    // Ensure dialog is shown for at least 500ms
    await Future.wait([
      operation,
      Future.delayed(const Duration(milliseconds: 500)),
    ]);

    if (context.mounted) {
      _logger.i('Dismissing loading dialog'); // Debug log
      Navigator.of(context).pop();
    } else {
      _logger.w('Context not mounted, cannot dismiss dialog'); // Debug log
    }
  }

  Future<bool?> _showConfirmationDialog(
      BuildContext context, String action, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $action'),
        content: Text('$action admin access for $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Consumer<AdminManagementViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return LayoutBuilder(
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
                            onPressed: () => viewModel.searchUsersAndAdmins(_searchController.text),
                          ),
                        ),
                        onSubmitted: (value) => viewModel.searchUsersAndAdmins(value),
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
                      viewModel.filteredUsers.isEmpty
                          ? Padding(
                        padding: EdgeInsets.symmetric(vertical: getPadding(8, 16)),
                        child: const Text('No users found'),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: viewModel.filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = viewModel.filteredUsers[index];
                          final imageUrl = user.image != null && user.image!.isNotEmpty
                              ? 'https://theemaeducation.com/${user.image}'
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
                                user.fullName ?? 'No Name',
                                style: TextStyle(fontSize: getFontSize(16, 22)),
                              ),
                              subtitle: Text(
                                user.email ?? 'No Email',
                                style: TextStyle(fontSize: getFontSize(13, 18)),
                              ),
                              trailing: ElevatedButton(
                                onPressed: viewModel.isActionLoading
                                    ? null
                                    : () async {
                                  final confirm = await _showConfirmationDialog(
                                    context,
                                    'Grant',
                                    user.fullName ?? 'No Name',
                                  );
                                  if (confirm == true) {
                                     _showLoadingDialog(
                                      context,
                                      viewModel.grantAdminAccess(context, user),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: getPadding(12, 24),
                                    vertical: getPadding(8, 14),
                                  ),
                                ),
                                child: viewModel.isActionLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                                    : Text(
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
                      viewModel.filteredAdmins.isEmpty
                          ? Padding(
                        padding: EdgeInsets.symmetric(vertical: getPadding(8, 16)),
                        child: const Text('No admins found'),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: viewModel.filteredAdmins.length,
                        itemBuilder: (context, index) {
                          final admin = viewModel.filteredAdmins[index];
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
                                admin.fullName ?? 'No Name',
                                style: TextStyle(fontSize: getFontSize(16, 22)),
                              ),
                              subtitle: Text(
                                admin.email ?? 'No Email',
                                style: TextStyle(fontSize: getFontSize(13, 18)),
                              ),
                              trailing: ElevatedButton(
                                onPressed: viewModel.isActionLoading
                                    ? null
                                    : () async {
                                  final confirm = await _showConfirmationDialog(
                                    context,
                                    'Remove',
                                    admin.fullName ?? 'No Name',
                                  );
                                  if (confirm == true) {
                                     _showLoadingDialog(
                                      context,
                                      viewModel.removeAdminAccess(context, admin),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: getPadding(12, 24),
                                    vertical: getPadding(8, 14),
                                  ),
                                ),
                                child: viewModel.isActionLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                                    : Text(
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
            );
          },
        ),
      ),
    );
  }
}