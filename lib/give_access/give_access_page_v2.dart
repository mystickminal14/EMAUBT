import 'package:ema_app/give_access/components/folder_content_tab.dart';
import 'package:ema_app/give_access/components/user_&_admin.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GiveAccessPage extends StatefulWidget {
  const GiveAccessPage({super.key});

  @override
  _GiveAccessPageState createState() => _GiveAccessPageState();
}

class _GiveAccessPageState extends State<GiveAccessPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, animationDuration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) => fetch());
  }

  Future<void> fetch() async {
    final userVM = Provider.of<ManageUserViewModel>(context, listen: false);
    userVM.roleFilter = 'user';
    await userVM.fetchUsers(context, refresh: true);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderTheme.surface,
      appBar: AppBar(
        backgroundColor: FolderTheme.primary,
        elevation: 0,
        title: const Text(
          'Grant Access',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FolderTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Users & Admins'),
            Tab(text: 'Files & Quizs')
          ],
        ),
      ),
      body: Consumer4<AccessControlViewModel, ManageUserViewModel,
          FolderFilesViewModel, FolderQuizSetsViewModel>(
        builder: (context, accessVM, userVM, folderFilesVM, folderQuizSetsVM, child) =>
            Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    UsersAdminsTab(viewModel: accessVM, userViewModel: userVM),
                    FolderContentTab(
                      viewModel: accessVM,
                      folderViewModel: folderFilesVM,
                      folderQuizSetsVM: folderQuizSetsVM,  // ← ADD
                    ),
                  ],
                ),
                if (accessVM.isLoading || userVM.isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: FolderTheme.accent, strokeWidth: 2.5),
                  ),
              ],
            ),
      ),
    );
  }
}