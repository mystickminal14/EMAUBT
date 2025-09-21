import 'package:ema_app/grant_access_files.dart';
import 'package:ema_app/view_model/access_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GiveAccessPage extends StatefulWidget {
  const GiveAccessPage({super.key});

  @override
  _GiveAccessPageState createState() => _GiveAccessPageState();
}

class _GiveAccessPageState extends State<GiveAccessPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, animationDuration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GiveAccessViewModel>(context, listen: false).fetchInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grant Access'),
        backgroundColor: Colors.teal,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.tealAccent,
          tabs: const [
            Tab(text: 'Users & Admins'),
            Tab(text: 'Files & Quiz Sets'),
            Tab(text: 'Activated & Granted'),
          ],
        ),
      ),
      body: Consumer<GiveAccessViewModel>(
        builder: (context, viewModel, child) => viewModel.isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            UsersAdminsTab(viewModel: viewModel),
            FilesQuizSetsTab(viewModel: viewModel),
            ActivatedGrantedTab(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

class UsersAdminsTab extends StatefulWidget {
  final GiveAccessViewModel viewModel;
  const UsersAdminsTab({super.key, required this.viewModel});

  @override
  _UsersAdminsTabState createState() => _UsersAdminsTabState();
}

class _UsersAdminsTabState extends State<UsersAdminsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            child: _SearchField(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Users and Admins',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(height: 10),
          Consumer<GiveAccessViewModel>(
            builder: (context, viewModel, child) => _UserAdminList(viewModel: viewModel),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GiveAccessViewModel>(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: viewModel.searchController,
        decoration: InputDecoration(
          labelText: 'Search by Name or Email',
          hintText: 'Enter name or email',
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, color: Colors.teal), // Static search icon
              if (viewModel.searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: viewModel.clearSearch,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAdminList extends StatelessWidget {
  final GiveAccessViewModel viewModel;
  const _UserAdminList({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.filteredUsers.isEmpty && viewModel.filteredAdmins.isEmpty) {
      return const Center(
        child: Text('No users or admins found.', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (viewModel.filteredAdmins.isNotEmpty) ...[
          const Text('Admins:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          ListView.builder(
            key: const Key('admin_list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.filteredAdmins.length,
            itemBuilder: (context, index) {
              final admin = viewModel.filteredAdmins[index];
              final matchingUsers = viewModel.filteredUsers.where((user) => user.email == admin.email || user.fullName == admin.fullName);
              return Card(
                elevation: 4,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _AdminUserItem(
                    entity: admin,
                    isAdmin: true,
                    matchingUsers: matchingUsers,
                    viewModel: viewModel,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        if (viewModel.filteredUsers.where((user) => !viewModel.filteredAdmins.any((admin) => admin.email == user.email || admin.fullName == user.fullName)).isNotEmpty) ...[
          const Text('Users:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          ListView.builder(
            key: const Key('user_list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.filteredUsers.where((user) => !viewModel.filteredAdmins.any((admin) => admin.email == user.email || admin.fullName == user.fullName)).length,
            itemBuilder: (context, index) {
              final user = viewModel.filteredUsers.where((user) => !viewModel.filteredAdmins.any((admin) => admin.email == user.email || admin.fullName == user.fullName)).elementAt(index);
              return Card(
                elevation: 4,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _AdminUserItem(
                    entity: user,
                    isAdmin: false,
                    matchingUsers: const [],
                    viewModel: viewModel,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _AdminUserItem extends StatelessWidget {
  final dynamic entity;
  final bool isAdmin;
  final Iterable<dynamic> matchingUsers;
  final GiveAccessViewModel viewModel;

  const _AdminUserItem({required this.entity, required this.isAdmin, required this.matchingUsers, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${isAdmin ? 'Admin' : 'User'}: ${entity.fullName} (${entity.email})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => _showGrantAccessDialog(context, entity, isAdmin, viewModel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              ),
              child: const Text('Grant Access'),
            ),
          ],
        ),
        if (matchingUsers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Matching Users:', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
          const SizedBox(height: 4),
          ...matchingUsers.map((user) => Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('- ${user.fullName} (${user.email})', style: const TextStyle(fontSize: 14))),
                ElevatedButton(
                  onPressed: () => _showGrantAccessDialog(context, user, false, viewModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  child: const Text('Grant Access'),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class FilesQuizSetsTab extends StatefulWidget {
  final GiveAccessViewModel viewModel;
  const FilesQuizSetsTab({super.key, required this.viewModel});

  @override
  _FilesQuizSetsTabState createState() => _FilesQuizSetsTabState();
}

class _FilesQuizSetsTabState extends State<FilesQuizSetsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Consumer<GiveAccessViewModel>(
        builder: (context, viewModel, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ElevatedButton.icon(
                  onPressed: () async => await _handleAsyncAction(
                    context,
                    action: viewModel.activateAll,
                    successMessage: 'Successfully activated ${viewModel.files.length + viewModel.quizSets.where((quiz) => !(quiz.folderId == 1 && viewModel.quizSets.isNotEmpty && quiz.id == viewModel.quizSets.first.id)).length} items',
                    loadingMessage: 'Activating all items...',
                  ),
                  icon: const Icon(Icons.power, size: 18),
                  label: const Text('Activate All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            viewModel.files.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No files available')))
                : ListView.builder(
              key: const Key('file_list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.files.length,
              itemBuilder: (context, index) {
                final file = viewModel.files[index];
                final isActivated = file.isActivated ?? false;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    title: Text(file.name ?? 'Unnamed File'),
                    subtitle: Text('ID: ${file.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: isActivated
                              ? null
                              : () async => await _handleAsyncAction(
                            context,
                            action: () => viewModel.toggleFileActivation(file.id!, false),
                            successMessage: 'File activated successfully',
                            loadingMessage: 'Activating file...',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                          ),
                          child: const Text('Activate'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: !isActivated
                              ? null
                              : () async => await _handleAsyncAction(
                            context,
                            action: () => viewModel.toggleFileActivation(file.id!, true),
                            successMessage: 'File deactivated successfully',
                            loadingMessage: 'Deactivating file...',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                          ),
                          child: const Text('Deactivate'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Quiz Sets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            viewModel.quizSets.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No quiz sets available')))
                : ListView.builder(
              key: const Key('quiz_list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.quizSets.length,
              itemBuilder: (context, index) {
                final quizSet = viewModel.quizSets[index];
                final isFree = quizSet.folderId == 1 && viewModel.quizSets.isNotEmpty && quizSet.id == viewModel.quizSets.first.id;
                final isActivated = quizSet.isActivated ?? false;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.quiz, color: Colors.green),
                    title: Text(
                      quizSet.name ?? 'Unnamed Quiz Set',
                      style: TextStyle(color: isFree ? Colors.grey : null),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${quizSet.id}'),
                        if (isFree) const Text('Free for all (Folder 1, First Quiz)', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                    trailing: isFree
                        ? null
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: isActivated
                              ? null
                              : () async => await _handleAsyncAction(
                            context,
                            action: () => viewModel.toggleQuizSetActivation(quizSet.id!, false),
                            successMessage: 'Quiz set activated successfully',
                            loadingMessage: 'Activating quiz set...',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                          ),
                          child: const Text('Activate'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: !isActivated
                              ? null
                              : () async => await _handleAsyncAction(
                            context,
                            action: () => viewModel.toggleQuizSetActivation(quizSet.id!, true),
                            successMessage: 'Quiz set deactivated successfully',
                            loadingMessage: 'Deactivating quiz set...',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                          ),
                          child: const Text('Deactivate'),
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
    );
  }
}

class ActivatedGrantedTab extends StatefulWidget {
  final GiveAccessViewModel viewModel;
  const ActivatedGrantedTab({super.key, required this.viewModel});

  @override
  _ActivatedGrantedTabState createState() => _ActivatedGrantedTabState();
}

class _ActivatedGrantedTabState extends State<ActivatedGrantedTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Consumer<GiveAccessViewModel>(
        builder: (context, viewModel, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activated Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (viewModel.selectedItems.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Confirm Mass Deletion'),
                        content: Text('Are you sure you want to delete ${viewModel.selectedItems.length} selected items?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await _handleAsyncAction(
                                context,
                                action: viewModel.deleteSelectedItems,
                                successMessage: 'Successfully deleted selected items',
                                loadingMessage: 'Deleting selected items...',
                              );
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ActivatedItems(viewModel: viewModel),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Granted Files and Quiz Sets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            viewModel.grantedItems.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No items granted yet')))
                : ListView.builder(
              key: const Key('granted_list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.grantedItems.length,
              itemBuilder: (context, index) {
                final permission = viewModel.grantedItems[index];
                final itemType = permission.itemType == 'file' ? 'File' : 'Quiz Set';
                final itemName = permission.itemName ?? 'Unnamed $itemType';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      permission.itemType == 'file' ? Icons.insert_drive_file : Icons.quiz,
                      color: permission.itemType == 'file' ? Colors.blue : Colors.green,
                    ),
                    title: Text('$itemType: $itemName'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivatedItems extends StatelessWidget {
  final GiveAccessViewModel viewModel;
  const _ActivatedItems({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.activatedItems.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No items activated')));
    }

    return ListView.builder(
      key: const Key('activated_list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: viewModel.activatedItems.length,
      itemBuilder: (context, index) {
        final item = viewModel.activatedItems[index];
        final isSelected = viewModel.selectedItems.contains(item.itemId);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) => viewModel.toggleItemSelection(item.itemId!),
              activeColor: Colors.teal,
            ),
            title: Text('${item.itemType == 'file' ? 'File' : 'Quiz Set'}: ${item.itemName ?? 'Unnamed ${item.itemType == 'file' ? 'File' : 'Quiz Set'}'}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async => await _handleAsyncAction(
                context,
                action: () => viewModel.deleteActivatedItem(item.itemId!, item.itemType!),
                successMessage: '${item.itemType} deleted successfully',
                loadingMessage: 'Deleting ${item.itemType}...',
              ),
              tooltip: 'Delete',
            ),
          ),
        );
      },
    );
  }
}

void _showGrantAccessDialog(BuildContext context, dynamic entity, bool isAdmin, GiveAccessViewModel viewModel) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Grant Access'),
      content: Text('Are you sure you want to grant access to this ${isAdmin ? 'admin' : 'user'}: ${entity.fullName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GrantAccessFilesPage(entity: entity.toJson(), isAdmin: isAdmin),
              ),
            ).then((result) {
              if (result == true) {
                viewModel.fetchGrantedItems();
              }
            });
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _handleAsyncAction(
    BuildContext context, {
      required Future<void> Function() action,
      required String successMessage,
      required String loadingMessage,
    }) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(color: Colors.teal),
          const SizedBox(width: 20),
          Text(loadingMessage),
        ],
      ),
    ),
  );
  try {
    await action();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('FetchDataException: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}