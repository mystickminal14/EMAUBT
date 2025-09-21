import 'package:ema_app/view_model/access_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/grant_access_files.dart';


class GiveAccessPage extends StatelessWidget {
  const GiveAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GiveAccessViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Users and Admins'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: viewModel.fetchData,
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
                    controller: viewModel.searchController,
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
                            onPressed: viewModel.searchUsersAndAdmins,
                          ),
                          if (viewModel.searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: viewModel.clearSearch,
                            ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => viewModel.searchUsersAndAdmins(),
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
              _buildUserAdminList(context, viewModel),
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
                    onPressed: () async {
                      try {
                        await viewModel.activateAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Successfully activated items'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );

                      }
                    },
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
              viewModel.files.isEmpty
                  ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No files available'),
                ),
              )
                  : Column(
                children: viewModel.files.map((file) {
                  final isActivated = file.isActivated;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                      title: Text(file.name ?? 'Unnamed File'),
                      subtitle: Text('ID: ${file.id}'),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.power,
                          color: isActivated==true ? Colors.green : Colors.grey,
                        ),
                        onPressed: () async {
                          try {
                            await viewModel.toggleFileActivation(file.id!, isActivated!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'File ${!isActivated ? 'activated' : 'deactivated'} successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        tooltip:  isActivated==true ? 'Deactivate' : 'Activate',
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
              viewModel.quizSets.isEmpty
                  ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No quiz sets available'),
                ),
              )
                  : Column(
                children: viewModel.quizSets.map((quizSet) {
                  final isFree = quizSet.folderId == 1 &&
                      viewModel.quizSets.isNotEmpty &&
                      quizSet.id == viewModel.quizSets.first.id;
                  final isActivated = quizSet.isActivated;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.quiz, color: Colors.green),
                      title: Text(
                        quizSet.name ?? 'Unnamed Quiz Set',
                        style: TextStyle(
                          color: isFree ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${quizSet.id}'),
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
                          color:  isActivated==true ? Colors.green : Colors.grey,
                        ),
                        onPressed: isFree
                            ? null
                            : () async {
                          try {
                            await viewModel.toggleQuizSetActivation(quizSet.id!, isActivated!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Quiz set ${!isActivated ? 'activated' : 'deactivated'} successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        tooltip:  isActivated==true ? 'Deactivate' : 'Activate',
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
                  if (viewModel.selectedItems.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await viewModel.deleteSelectedItems();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Successfully deleted selected items'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
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
              _buildActivatedItems(context, viewModel),
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
              viewModel.grantedItems.isEmpty
                  ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No items granted yet'),
                ),
              )
                  : Column(
                children: viewModel.grantedItems.map((permission) {
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
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAdminList(BuildContext context, GiveAccessViewModel viewModel) {
    if (viewModel.filteredUsers.isEmpty && viewModel.filteredAdmins.isEmpty) {
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
        if (viewModel.filteredAdmins.isNotEmpty) ...[
          const Text(
            'Admins:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...viewModel.filteredAdmins.map((admin) {
            final matchingUsers = viewModel.filteredUsers.where(
                    (user) => user.email == admin.email || user.fullName == admin.fullName);

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
                                    entity: admin.toJson(),
                                    isAdmin: true,
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  viewModel.fetchGrantedItems();
                                }
                              });
                            },
                            child: Text(
                              'Admin: ${admin.fullName} (${admin.email})',
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
                                  entity: user.toJson(),
                                  isAdmin: false,
                                ),
                              ),
                            ).then((result) {
                              if (result == true) {
                                viewModel.fetchGrantedItems();
                              }
                            });
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '- ${user.fullName} (${user.email})',
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
        if (viewModel.filteredUsers
            .where((user) => !viewModel.filteredAdmins
            .any((admin) => admin.email == user.email || admin.fullName == user.fullName))
            .isNotEmpty) ...[
          const Text(
            'Users:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...viewModel.filteredUsers
              .where((user) => !viewModel.filteredAdmins
              .any((admin) => admin.email == user.email || admin.fullName == user.fullName))
              .map((user) {
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
                                entity: user.toJson(),
                                isAdmin: false,
                              ),
                            ),
                          ).then((result) {
                            if (result == true) {
                              viewModel.fetchGrantedItems();
                            }
                          });
                        },
                        child: Text(
                          'User: ${user.fullName} (${user.email})',
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

  Widget _buildActivatedItems(BuildContext context, GiveAccessViewModel viewModel) {
    if (viewModel.activatedItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No items activated'),
        ),
      );
    }

    return Column(
      children: viewModel.activatedItems.map((item) {
        final isSelected = viewModel.selectedItems.contains(item.itemId);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                viewModel.toggleItemSelection(item.itemId!);
              },
            ),
            title: Text(
                '${item.itemType == 'file' ? 'File' : 'Quiz Set'}: ${item.itemName ?? 'Unnamed ${item.itemType == 'file' ? 'File' : 'Quiz Set'}'}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                try {
                  await viewModel.deleteActivatedItem(item.itemId!, item.itemType!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.itemType} deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              tooltip: 'Delete',
            ),
          ),
        );
      }).toList(),
    );
  }
}