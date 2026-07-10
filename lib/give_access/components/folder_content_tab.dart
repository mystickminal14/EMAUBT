import 'dart:convert';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/folder_model_v2.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/utils/responsive.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FolderContentTab extends StatefulWidget {
  final AccessControlViewModel viewModel;
  final FolderFilesViewModel folderViewModel;
  final FolderQuizSetsViewModel folderQuizSetsVM;

  const FolderContentTab({
    super.key,
    required this.viewModel,
    required this.folderViewModel,
    required this.folderQuizSetsVM,
  });
  @override
  State<FolderContentTab> createState() => _FolderContentTabState();
}

class _FolderContentTabState extends State<FolderContentTab>
    with AutomaticKeepAliveClientMixin {

  final ScrollController _scrollController = ScrollController();
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UpdatedFolderViewModel>().fetchFolders(context, refresh: true);
    });
  }
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final vm = context.read<UpdatedFolderViewModel>();
      if (!vm.isFetchingMore && !vm.isLoading && vm.hasMorePages) {
        vm.fetchNextPage(context);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose(); // ← add
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<UpdatedFolderViewModel>(
      builder: (context, folderVM, _) {
        if (folderVM.isLoading && folderVM.filteredFolders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        if (folderVM.filteredFolders.isEmpty) {
          return const _FolderEmptyMessage();
        }

        return RefreshIndicator(
          color: FolderTheme.accent,
          backgroundColor: Colors.white,
          onRefresh: () => folderVM.fetchFolders(context, refresh: true),
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Folders', style: FolderTheme.screenTitle),
                      const SizedBox(height: 2),
                      Text(
                        'Select a folder to manage access',
                        style: FolderTheme.screenSubtitle,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FolderTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${folderVM.filteredFolders.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FolderTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...List.generate(folderVM.filteredFolders.length, (i) {
                final folder = folderVM.filteredFolders[i];
                return _FolderAccessCard(
                  folder: folder,
                  index: i,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderContentDetailScreen(
                        folder: folder,
                        accessVM: widget.viewModel,
                        folderFilesVM: FolderFilesViewModel(),
                        folderQuizSetsVM: FolderQuizSetsViewModel(),
                      ),
                    ),
                  ),
                );
              }),
              if (folderVM.isFetchingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: FolderTheme.accent, strokeWidth: 2),
                  ),
                ),
            ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Folder card with proper image handling ──────────────────────────────────
class _FolderAccessCard extends StatelessWidget {
  final FolderModelv2 folder;
  final int index;
  final VoidCallback onTap;

  const _FolderAccessCard({
    required this.folder,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 35)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: child,
          )),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: FolderTheme.cardDecoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _FolderIconBox(iconPath: folder.iconPath),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name ?? 'Unnamed Folder',
                            style: FolderTheme.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: FolderTheme.accent.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Tap to manage files & quiz sets',
                                style: FolderTheme.cardSubtitle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: FolderTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: FolderTheme.accent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Folder Icon Box with Network/Base64 support ─────────────────────────────
class _FolderIconBox extends StatelessWidget {
  final String? iconPath;

  const _FolderIconBox({this.iconPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: FolderTheme.iconContainerDecoration,
      clipBehavior: Clip.antiAlias,
      child: _buildIconChild(),
    );
  }

  Widget _buildIconChild() {
    final raw = iconPath;

    if (raw == null || raw.isEmpty) {
      return const _FallbackIcon(size: 26);
    }

    // Check if it's Base64
    if (_isBase64(raw)) {
      try {
        final bytes = base64Decode(raw);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, error, __) {
            debugPrint("❌ Base64 decode error: $error");
            return const _FallbackIcon(size: 26);
          },
        );
      } catch (e) {
        debugPrint("❌ Failed to decode Base64: $e");
        return const _FallbackIcon(size: 26);
      }
    }

    // Treat as URL/path
    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();
    debugPrint("🖼️ Folder Icon URL => $fullUrl");

    return FutureBuilder<Map<String, String>>(
      future: getAuthHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Image.network(
          fullUrl,
          headers: snapshot.data,
          fit: BoxFit.cover,
          errorBuilder: (_, error, __) {
            debugPrint("❌ Image load failed => $fullUrl, Error: $error");
            return const _FallbackIcon(size: 26);
          },
        );
      },
    );
  }

  bool _isBase64(String str) {
    if (str.length < 20) return false;
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
    return base64Pattern.hasMatch(str);
  }
}

// ─── File Icon Box with Network support ──────────────────────────────────────
class _FileIconBox extends StatelessWidget {
  final String? iconPath;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const _FileIconBox({
    this.iconPath,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: fallbackColor.withOpacity(0.25)),
      ),
      child: _buildIconChild(),
    );
  }

  Widget _buildIconChild() {
    final raw = iconPath;

    if (raw == null || raw.isEmpty) {
      return Icon(fallbackIcon, color: fallbackColor, size: 20);
    }

    // Check if it's Base64
    if (_isBase64(raw)) {
      try {
        final bytes = base64Decode(raw);
        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, error, __) {
              debugPrint("❌ File Base64 decode error: $error");
              return Icon(fallbackIcon, color: fallbackColor, size: 20);
            },
          ),
        );
      } catch (e) {
        debugPrint("❌ Failed to decode file Base64: $e");
        return Icon(fallbackIcon, color: fallbackColor, size: 20);
      }
    }

    // Treat as URL/path
    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();
    debugPrint("🖼️ File Icon URL => $fullUrl");

    return FutureBuilder<Map<String, String>>(
      future: getAuthHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fallbackColor,
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.network(
            fullUrl,
            headers: snapshot.data,
            fit: BoxFit.cover,
            errorBuilder: (_, error, __) {
              debugPrint("❌ File image load failed => $fullUrl, Error: $error");
              return Icon(fallbackIcon, color: fallbackColor, size: 20);
            },
          ),
        );
      },
    );
  }

  bool _isBase64(String str) {
    if (str.length < 20) return false;
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
    return base64Pattern.hasMatch(str);
  }
}

// ─── Fallback Icon ───────────────────────────────────────────────────────────
class _FallbackIcon extends StatelessWidget {
  final double size;

  const _FallbackIcon({this.size = 26});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.folder_rounded,
        size: size,
        color: FolderTheme.accent,
      ),
    );
  }
}

// ─── Empty message ────────────────────────────────────────────────────────────
class _FolderEmptyMessage extends StatelessWidget {
  const _FolderEmptyMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FolderTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 38, color: FolderTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No folders found', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Create folders to manage access control.',
            style: FolderTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Detail Screen — per-folder files & quiz sets with assign-type controls
// ═════════════════════════════════════════════════════════════════════════════

class FolderContentDetailScreen extends StatefulWidget {
  final FolderModelv2 folder;
  final AccessControlViewModel accessVM;
  final FolderFilesViewModel folderFilesVM;
  final FolderQuizSetsViewModel folderQuizSetsVM;

  const FolderContentDetailScreen({
    super.key,
    required this.folder,
    required this.accessVM,
    required this.folderFilesVM,
    required this.folderQuizSetsVM,
  });

  @override
  State<FolderContentDetailScreen> createState() =>
      _FolderContentDetailScreenState();
}

class _FolderContentDetailScreenState
    extends State<FolderContentDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.folderFilesVM.reset();
      widget.folderQuizSetsVM.reset();

      widget.folderFilesVM.fetchFiles(context, widget.folder.id!);
      widget.folderQuizSetsVM.fetchQuizSets(context, widget.folder.id!);
    });
  }
  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;

    final folderId = widget.folder.id!;

    // Load more files
    if (!widget.folderFilesVM.isFetchingMore &&
        !widget.folderFilesVM.isLoading &&
        widget.folderFilesVM.hasMorePages) {
      widget.folderFilesVM.fetchNextPage(context, folderId);
    }

    // Load more quiz sets
    if (!widget.folderQuizSetsVM.isFetchingMore &&
        !widget.folderQuizSetsVM.isLoading &&
        widget.folderQuizSetsVM.hasMorePages) {
      widget.folderQuizSetsVM.fetchNextPage(context, folderId);
    }
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AccessControlViewModel>.value(value: widget.accessVM),
        ChangeNotifierProvider<FolderFilesViewModel>.value(value: widget.folderFilesVM),
        ChangeNotifierProvider<FolderQuizSetsViewModel>.value(value: widget.folderQuizSetsVM),
      ],
      child: Scaffold(
        backgroundColor: FolderTheme.surface,
        appBar: AppBar(
          backgroundColor: FolderTheme.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              _FolderIconBox(iconPath: widget.folder.iconPath),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.folder.name ?? 'Folder Content',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: Consumer3<FolderFilesViewModel, FolderQuizSetsViewModel, AccessControlViewModel>(
          builder: (context, filesVM, quizVM, accessVM, _) {
            if (filesVM.isLoading || quizVM.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                    color: FolderTheme.accent, strokeWidth: 2.5),
              );
            }

            final files = filesVM.filteredFiles;
            final quizSets = quizVM.filteredQuizSets;

            return RefreshIndicator(
              color: FolderTheme.accent,
              backgroundColor: Colors.white,
              onRefresh: () => filesVM.fetchFiles(context, widget.folder.id!),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ResponsiveCenter(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                tabletMaxWidth: 700,
                desktopMaxWidth: 860,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _AssignTypeLegend(),
                    const SizedBox(height: 24),

                    _SectionHeader(label: 'Files', count: files.length),
                    const SizedBox(height: 10),
                    files.isEmpty
                        ? const _EmptyContent(
                      icon: Icons.insert_drive_file_outlined,
                      message: 'No files in this folder',
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: files.length,
                      itemBuilder: (_, i) {

                        final file = files[i];
                        return _AssignTypeCard(
                          icon: Icons.insert_drive_file_rounded,
                          iconColor: FolderTheme.accent,
                          title: file.name ?? 'Unnamed File',
                          subtitle: 'ID: ${file.id}',
                          currentType: file.accessType ?? 'all',
                          index: i,
                          iconPath: file.iconPath,
                          onTypeChanged: (type) =>
                              accessVM.updateFileAssignType(
                                  context,filesVM,widget.folder.id!, file.id!, type),
                        );
                      },
                    ),
                    if (filesVM.isFetchingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: FolderTheme.accent, strokeWidth: 2),
                        ),
                      ),
                    const SizedBox(height: 28),

                    _SectionHeader(label: 'Quiz Sets', count: quizSets.length),
                    const SizedBox(height: 10),
                    quizSets.isEmpty
                        ? const _EmptyContent(
                      icon: Icons.quiz_outlined,
                      message: 'No quiz sets in this folder',
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quizSets.length,
                      itemBuilder: (_, i) {
                        final quiz = quizSets[i];
                        return _AssignTypeCard(
                          icon: Icons.quiz_rounded,
                          iconColor: const Color(0xFF22C55E),
                          title: quiz.name ?? 'Unnamed Quiz Set',
                          subtitle: 'ID: ${quiz.id}',
                          currentType: quiz.access_type ?? 'all',
                          index: i,
                          iconPath: quiz.iconPath,
                          onTypeChanged: (type) =>
                              accessVM.updateQuizSetAssignType(
                                  context,quizVM,widget.folder.id!, quiz.id!, type),
                        );
                      },
                    ),
                    if (quizVM.isFetchingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: FolderTheme.accent, strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Assign type card with image support ─────────────────────────────────────
class _AssignTypeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String currentType;
  final int index;
  final String? iconPath;
  final void Function(String type) onTypeChanged;

  const _AssignTypeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.currentType,
    required this.index,
    this.iconPath,
    required this.onTypeChanged,
  });

  static const _typeInfo = {
    'all': (label: 'All', color: Color(0xFF4F8EF7)),
    'logged_in': (label: 'Members', color: Color(0xFFF59E0B)),
    'private': (label: 'Private', color: Color(0xFFEF4444)),
  };

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo[currentType] ??
        (label: 'All', color: const Color(0xFF4F8EF7));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 180 + (index.clamp(0, 8) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: FolderTheme.cardDecoration,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FileIconBox(
                  iconPath: iconPath,
                  fallbackIcon: icon,
                  fallbackColor: iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FolderTheme.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: FolderTheme.cardSubtitle),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: info.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: info.color.withOpacity(0.4)),
                  ),
                  child: Text(
                    info.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: info.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AssignTypeSelector(
              currentType: currentType,
              onTypeChanged: onTypeChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Segmented assign-type selector ──────────────────────────────────────────
class _AssignTypeSelector extends StatelessWidget {
  final String currentType;
  final void Function(String) onTypeChanged;

  const _AssignTypeSelector({
    required this.currentType,
    required this.onTypeChanged,
  });

  static const _options = [
    _AssignOption(
      value: 'all',
      label: 'All',
      icon: Icons.public_rounded,
      color: Color(0xFF4F8EF7),
      description: 'Everyone',
    ),
    _AssignOption(
      value: 'logged_in',
      label: 'Members',
      icon: Icons.lock_open_rounded,
      color: Color(0xFFF59E0B),
      description: 'Logged in users',
    ),
    _AssignOption(
      value: 'private',
      label: 'Private',
      icon: Icons.lock_rounded,
      color: Color(0xFFEF4444),
      description: 'Restricted',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.asMap().entries.map((e) {
        final i = e.key;
        final opt = e.value;
        final isSelected = currentType == opt.value;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 5,
              right: i == _options.length - 1 ? 0 : 5,
            ),
            child: GestureDetector(
              onTap: isSelected ? null : () => onTypeChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? opt.color.withOpacity(0.1)
                      : FolderTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? opt.color.withOpacity(0.6)
                        : FolderTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? opt.color.withOpacity(0.15)
                            : FolderTheme.border.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        opt.icon,
                        size: 15,
                        color: isSelected
                            ? opt.color
                            : FolderTheme.textSub,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? opt.color
                            : FolderTheme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AssignOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const _AssignOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

// ─── Assign type legend ──────────────────────────────────────────────────────
class _AssignTypeLegend extends StatelessWidget {
  const _AssignTypeLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FolderTheme.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FolderTheme.accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: FolderTheme.accent),
              SizedBox(width: 6),
              Text(
                'Access Types',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FolderTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _LegendItem(
            color: Color(0xFF4F8EF7),
            icon: Icons.public_rounded,
            label: 'All',
            desc: 'Visible to everyone including guests',
          ),
          const SizedBox(height: 5),
          const _LegendItem(
            color: Color(0xFFF59E0B),
            icon: Icons.lock_open_rounded,
            label: 'Members',
            desc: 'Only logged-in users can access',
          ),
          const SizedBox(height: 5),
          const _LegendItem(
            color: Color(0xFFEF4444),
            icon: Icons.lock_rounded,
            label: 'Private',
            desc: 'Restricted — manually granted access only',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String desc;

  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          '$label — ',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color),
        ),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(fontSize: 11, color: FolderTheme.textSub),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: FolderTheme.textMain,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FolderTheme.accent,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty content placeholder ────────────────────────────────────────────────
class _EmptyContent extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyContent({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: FolderTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: FolderTheme.border,
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: FolderTheme.border),
          const SizedBox(height: 8),
          Text(
            message,
            style: FolderTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}