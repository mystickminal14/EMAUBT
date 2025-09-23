import 'package:ema_app/screens/admin/add_edit_delete_admins.dart';
import 'package:ema_app/give_access_page.dart';
import 'package:ema_app/free_quiz_and_files_page.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import '../users/user_home_page.dart';
import 'admin_folders_page.dart';
import 'add_edit_delete_users.dart';
import 'admin_notices_page.dart';
import '../auth/login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final String fullName;
  final String profileImage;
  final bool isAdmin;
  final String userEmail;

  const AdminDashboardPage({
    super.key,
    required this.fullName,
    required this.profileImage,
    required this.isAdmin,
    required this.userEmail,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  void _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final userViewModel = UserViewModel();
      await userViewModel.removeUser();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(
            userIdentifier: '',
            isAdmin: false,
            fullName: '',
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildDashboardButton(context, Icons.home, "User Home Page", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserHomePage(
                    fullName: widget.fullName,
                    profileImage: widget.profileImage,
                    isAdmin: widget.isAdmin,
                    accessedFromAdminDashboard: true,
                    userEmail: widget.userEmail,
                    userIdentifier: '',
                    folderId: null,
                    folderName: '',
                  ),
                ),
              );
            }),
            _buildDashboardButton(context, Icons.folder_open, "Folders", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FoldersPage()),
              );
            }),
            _buildDashboardButton(
                context, Icons.admin_panel_settings, "Add/Edit/Delete Admins",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddEditDeleteAdminsPage()),
              );
            }),
            _buildDashboardButton(context, Icons.group, "Add/Edit/Delete Users",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddEditDeleteUsersPage()),
              );
            }),
            _buildDashboardButton(
                context, Icons.notifications, "Important Information", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NoticesPage()),
              );
            }),
            _buildDashboardButton(context, Icons.vpn_key, "Give Access", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GiveAccessPage()),
              );
            }),
            _buildDashboardButton(context, Icons.quiz, "Free Quiz & Files", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FreeQuizAndFilesPage()),
              );
            }),
            _buildDashboardButton(
              context,
              Icons.exit_to_app,
              "Logout",
              () {
                _handleLogout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context, IconData icon,
      String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
