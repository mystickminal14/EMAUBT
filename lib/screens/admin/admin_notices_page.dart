import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/notice_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textContentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<NoticeV>();
    viewModel.fetchNotices(context);
    _searchController.addListener(() {
      viewModel.searchNotices(_searchController.text);
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
      BuildContext context, String action, String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm $action',
            style: Theme.of(context).textTheme.titleLarge),
        content: Text('$action notice "$title"?',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _editNotice(BuildContext context, NoticeModel notice,
      NoticeManagementViewModel viewModel) async {
    viewModel.setFields(
      title: notice.title,
      textContent: notice.textContent,
      files: notice.files
          ?.map((file) =>
          PlatformFile(name: file.fileName ?? '', path: file.filePath, size: 0))
          .toList() ??
          [],
    );
    _titleController.text = notice.title ?? '';
    _textContentController.text = notice.textContent ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Edit Notice",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Card(
            elevation: 2,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Consumer<NoticeManagementViewModel>(
                builder: (context, vm, _) => Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: "Title (required)",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Title is required'
                            : null,
                        onChanged: (value) => vm.setFields(
                            title: value,
                            textContent: vm.textContent,
                            files: vm.selectedFiles),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _textContentController,
                        decoration: InputDecoration(
                          labelText: "Text Content (optional)",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        maxLines: 3,
                        onChanged: (value) => vm.setFields(
                            title: vm.title,
                            textContent: value,
                            files: vm.selectedFiles),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.upload_file),
                        label: Text(vm.selectedFiles.isNotEmpty
                            ? "Change Files (${vm.selectedFiles.length})"
                            : "Pick Files"),
                        onPressed: () async {
                          await vm.pickFiles();
                          setState(() {}); // Refresh UI after file selection
                        },
                      ),
                      const SizedBox(height: 16),
                      if (vm.selectedFiles.isNotEmpty)
                        ...vm.selectedFiles.map((file) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(file.name,
                                      style: const TextStyle(fontSize: 14))),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  vm.selectedFiles.remove(file);
                                  notifyListeners();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ))
                      else if (notice.files != null && notice.files!.isNotEmpty)
                        ...notice.files!.map((file) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(file.fileName ?? '',
                                      style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        )),
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
            child: Text('Cancel',
                style:
                TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final confirm = await _showConfirmationDialog(
                    context, 'Edit', notice.title ?? 'this notice');
                if (confirm == true) {
                  _showLoadingDialog(context);
                  await viewModel.editNotice(context, notice);
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close loading dialog
                  }
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Close edit dialog
                  }
                  _titleController.clear();
                  _textContentController.clear();
                  viewModel.clearFields();
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, Files file) async {
    if (file.filePath != null) {
      final uri = Uri.parse(file.filePath!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${file.fileName}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No URL available for file: ${file.fileName}')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textContentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NoticeManagementViewModel>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;
    double getFontSize(double mobile, double tablet) =>
        isWide ? tablet : mobile;
    double getPadding(double mobile, double tablet) => isWide ? tablet : mobile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Manage Notices",
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Notices",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: getFontSize(20, 24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: "Search by Title or Content",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainer,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => viewModel
                                .searchNotices(_searchController.text),
                          ),
                        ),
                        style: TextStyle(fontSize: getFontSize(14, 16)),
                        onFieldSubmitted: (value) =>
                            viewModel.searchNotices(value),
                      ),
                      const SizedBox(height: 12),
                      viewModel.filteredNotices.isEmpty
                          ? Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: getPadding(8, 16)),
                        child: Text(
                          'No notices found',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontSize: getFontSize(14, 16),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics:
                        const NeverScrollableScrollPhysics(),
                        itemCount: viewModel.filteredNotices.length,
                        itemBuilder: (context, index) {
                          final notice =
                          viewModel.filteredNotices[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12)),
                            margin: EdgeInsets.symmetric(
                                vertical: getPadding(6, 8)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notice.title ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                            fontSize:
                                            getFontSize(
                                                16, 18),
                                            fontWeight:
                                            FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit,
                                                color: Theme.of(
                                                    context)
                                                    .colorScheme
                                                    .primary),
                                            onPressed: viewModel
                                                .isActionLoading
                                                ? null
                                                : () => _editNotice(
                                                context,
                                                notice,
                                                viewModel),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Theme.of(
                                                    context)
                                                    .colorScheme
                                                    .error),
                                            onPressed: viewModel
                                                .isActionLoading
                                                ? null
                                                : () async {
                                              final confirm =
                                              await _showConfirmationDialog(
                                                context,
                                                'Delete',
                                                notice.title ??
                                                    'this notice',
                                              );
                                              if (confirm ==
                                                  true) {
                                                _showLoadingDialog(
                                                    context);
                                                await viewModel
                                                    .deleteNotice(
                                                    context,
                                                    notice);
                                                if (Navigator
                                                    .of(
                                                    context)
                                                    .canPop()) {
                                                  Navigator.of(
                                                      context)
                                                      .pop(); // Close loading dialog
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (notice.textContent != null &&
                                      notice.textContent!.isNotEmpty)
                                    ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding:
                                        const EdgeInsets.all(
                                            8.0),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Theme.of(
                                                  context)
                                                  .colorScheme
                                                  .outline),
                                          borderRadius:
                                          BorderRadius.circular(
                                              8),
                                        ),
                                        child: Text(
                                          notice.textContent!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                            fontSize:
                                            getFontSize(
                                                14, 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  if (notice.files != null &&
                                      notice.files!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...notice.files!.map((file) {
                                      final isImage = file
                                          .fileName
                                          ?.toLowerCase()
                                          .endsWith('.jpg') ??
                                          false ||
                                              file.fileName
                                                  ?.toLowerCase()
                                                  .endsWith(
                                                  '.jpeg') ??
                                          false ||
                                              file.fileName
                                                  ?.toLowerCase()
                                                  .endsWith(
                                                  '.png') ??
                                          false;
                                      return GestureDetector(
                                        onTap: () =>
                                            _openFile(context, file),
                                        child: Padding(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              vertical: 4),
                                          child: isImage &&
                                              file.filePath !=
                                                  null
                                              ? ClipRRect(
                                            borderRadius:
                                            BorderRadius
                                                .circular(
                                                8),
                                            child:
                                            Image.network(
                                              file.filePath!,
                                              height:
                                              getFontSize(
                                                  100,
                                                  120),
                                              width: double
                                                  .infinity,
                                              fit:
                                              BoxFit.cover,
                                              errorBuilder: (context,
                                                  error,
                                                  stackTrace) =>
                                                  Text(
                                                    "Failed to load image: ${file.fileName}",
                                                    style:
                                                    TextStyle(
                                                      color: Theme.of(
                                                          context)
                                                          .colorScheme
                                                          .error,
                                                      fontSize:
                                                      getFontSize(
                                                          14,
                                                          16),
                                                    ),
                                                  ),
                                            ),
                                          )
                                              : Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .attach_file,
                                                  size: getFontSize(
                                                      20,
                                                      24),
                                                  color: Theme.of(
                                                      context)
                                                      .colorScheme
                                                      .primary),
                                              const SizedBox(
                                                  width: 8),
                                              Expanded(
                                                child: Text(
                                                  file.fileName ??
                                                      '',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                        context)
                                                        .colorScheme
                                                        .primary,
                                                    fontSize:
                                                    getFontSize(
                                                        14,
                                                        16),
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
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: viewModel.isActionLoading
            ? null
            : () {
          _titleController.clear();
          _textContentController.clear();
          viewModel.clearFields();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text(
                "Add Notice",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Consumer<NoticeManagementViewModel>(
                      builder: (context, vm, _) => Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: "Title (required)",
                                border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                              ),
                              validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Title is required'
                                  : null,
                              onChanged: (value) => vm.setFields(
                                  title: value,
                                  textContent: vm.textContent,
                                  files: vm.selectedFiles),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _textContentController,
                              decoration: InputDecoration(
                                labelText: "Text Content (optional)",
                                border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                              ),
                              maxLines: 3,
                              onChanged: (value) => vm.setFields(
                                  title: vm.title,
                                  textContent: value,
                                  files: vm.selectedFiles),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: Text(vm.selectedFiles.isNotEmpty
                                  ? "Change Files (${vm.selectedFiles.length})"
                                  : "Pick Files"),
                              onPressed: () async {
                                await vm.pickFiles();
                                setState(() {}); // Refresh UI
                              },
                            ),
                            if (vm.selectedFiles.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ...vm.selectedFiles.map((file) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(file.name,
                                            style: const TextStyle(
                                                fontSize: 14))),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 20),
                                      onPressed: () {
                                        vm.selectedFiles.remove(file);
                                        vm.notifyListeners();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              )),
                            ],
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
                  child: Text('Cancel',
                      style: TextStyle(
                          color:
                          Theme.of(context).colorScheme.secondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final confirm = await _showConfirmationDialog(
                        context,
                        'Add',
                        _titleController.text.isEmpty
                            ? 'this notice'
                            : _titleController.text,
                      );
                      if (confirm == true) {
                        _showLoadingDialog(context);
                        await viewModel.addNotice(context);
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context)
                              .pop(); // Close loading dialog
                        }
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop(); // Close add dialog
                        }
                        _titleController.clear();
                        _textContentController.clear();
                        viewModel.clearFields();
                      }
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}