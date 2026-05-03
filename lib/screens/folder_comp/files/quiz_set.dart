import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/new_quiz_set_model.dart';
import 'package:ema_app/screens/admin/admin_quiz_set_detail_page.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QuizSetsTab extends StatefulWidget {
  final int folderId;

  const QuizSetsTab({super.key, required this.folderId});

  @override
  State<QuizSetsTab> createState() => _QuizSetsTabState();
}

class _QuizSetsTabState extends State<QuizSetsTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _searchCtrl;er
  late final ScrollController _scrollCtrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FolderQuizSetsViewModel>()
          .fetchQuizSets(context, widget.folderId, refresh: true);
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 200) {
      return;
    }

    final vm = context.read<FolderQuizSetsViewModel>();
    if (vm.isFetchingMore || vm.isLoading || !vm.hasMorePages) return;
    vm.fetchNextPage(context, widget.folderId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<FolderQuizSetsViewModel>(
      builder: (_, vm, __) {
        return Column(
          children: [
            // Search + add row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(child: _SearchBar(controller: _searchCtrl)),
                  const SizedBox(width: 10),
                  _AddQuizSetButton(
                    onTap: () => _showFormSheet(context, vm, null),
                  ),
                ],
              ),
            ),
            // Total count
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '${vm.totalQuizSets} quiz set${vm.totalQuizSets == 1 ? '' : 's'} total',
                    style: FolderTheme.screenSubtitle,
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _QuizSetListBody(
                scrollController: _scrollCtrl,
                folderId: widget.folderId,
                onEdit: (q) => _showFormSheet(context, vm, q),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFormSheet(
      BuildContext context, FolderQuizSetsViewModel vm, QuizSetModel? existing) {
    if (existing != null) {
      // Seed existing values — for icon, pass overwriteIcon: true so existing
      // server icon is shown, but any freshly-picked icon already in vm is replaced.
      vm.setFields(
        name: existing.name,
        description: existing.description,
        durationMinutes: existing.durationMinutes,
        passingScore: existing.passingScore,
        isPublished: existing.isPublished ?? false,
        iconBase64: existing.iconPath, // seed existing icon from server
        overwriteIcon: true,
      );
      // Also clear any stale picked bytes so the preview uses the server icon
      vm.selectedIconBytes = null;
    } else {
      vm.clearFields();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: QuizSetFormSheet(
          existing: existing,
          onSubmit: (data) async {
            // FIX: capture icon BEFORE setFields so it is never lost
            final currentIcon = vm.selectedIconBase64;

            vm.setFields(
              name: data['name'],
              description: data['description'],
              durationMinutes: data['duration_minutes'],
              passingScore: data['passing_score'],
              isPublished: data['is_published'],
              iconBase64: currentIcon, // ← preserve whatever icon is active
              overwriteIcon: true,
            );

            if (existing == null) {
              await vm.addQuizSet(context, widget.folderId);
            } else {
              await vm.editQuizSet(context, existing, widget.folderId);
            }
          },
        ),
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: FolderTheme.searchDecoration,
      child: TextField(
        controller: controller,
        onChanged: (v) =>
            context.read<FolderQuizSetsViewModel>().searchQuizSets(v),
        style: FolderTheme.fieldInput,
        decoration: const InputDecoration(
          hintText: 'Search quiz sets…',
          hintStyle: TextStyle(color: FolderTheme.textSub, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: FolderTheme.textSub, size: 18),
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }
}

// ─── Add Button ───────────────────────────────────────────────────────────────
class _AddQuizSetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddQuizSetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: FolderTheme.accent,
        foregroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        elevation: 0,
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'New',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

// ─── Quiz Set List Body ───────────────────────────────────────────────────────
class _QuizSetListBody extends StatelessWidget {
  final ScrollController scrollController;
  final int folderId;
  final void Function(QuizSetModel) onEdit;

  const _QuizSetListBody({
    required this.scrollController,
    required this.folderId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderQuizSetsViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.filteredQuizSets.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }
        if (vm.filteredQuizSets.isEmpty) {
          return const _QuizSetsEmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount:
          vm.filteredQuizSets.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == vm.filteredQuizSets.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(
                        color: FolderTheme.accent, strokeWidth: 2)),
              );
            }
            final quizSet = vm.filteredQuizSets[i];
            return QuizSetCard(
              quizSet: quizSet,
              index: i,
              onEdit: () => onEdit(quizSet),
              onDelete: () => _confirmDelete(context, vm, quizSet),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, FolderQuizSetsViewModel vm,
      QuizSetModel quizSet) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Quiz Set',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Remove "${quizSet.name ?? 'this quiz set'}" permanently? This cannot be undone.',
          style: const TextStyle(color: FolderTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: FolderTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteQuizSet(context, quizSet, folderId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Quiz Set Card ────────────────────────────────────────────────────────────
class QuizSetCard extends StatelessWidget {
  final QuizSetModel quizSet;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const QuizSetCard({
    super.key,
    required this.quizSet,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: FolderTheme.cardDecoration,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizSetDetailPage(
                quizSetId:quizSet.id! ,
                quizSetName: quizSet.name!,
              ),
            ),
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: _QuizSetIconBox(iconPath: quizSet.iconPath),
            title: Text(
              quizSet.name ?? '—',
              style: FolderTheme.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    icon: Icons.help_outline_rounded,
                    label:
                    '${quizSet.questionCount ?? 0} Q${(quizSet.questionCount ?? 0) == 1 ? '' : 's'}',
                  ),
                  if (quizSet.durationMinutes != null)
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: '${quizSet.durationMinutes}m',
                    ),
                  if (quizSet.passingScore != null)
                    _InfoChip(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Pass: ${quizSet.passingScore}%',
                    ),
                  _PublishedBadge(isPublished: quizSet.isPublished ?? false),
                ],
              ),
            ),
            trailing: _QuizSetCardMenu(onEdit: onEdit, onDelete: onDelete),
          ),
        ),
      ),
    );
  }
}

// ─── Quiz Set Icon Box ────────────────────────────────────────────────────────
class _QuizSetIconBox extends StatelessWidget {
  final String? iconPath;

  const _QuizSetIconBox({this.iconPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: FolderTheme.iconContainerDecoration,
      clipBehavior: Clip.antiAlias,
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    if (iconPath == null || iconPath!.isEmpty) {
      return const Center(
        child: Icon(Icons.quiz_rounded, size: 28, color: FolderTheme.accent),
      );
    }

    // FIX: Handle "data:image/jpeg;base64,<data>" URI format
    if (iconPath!.startsWith('data:')) {
      try {
        final commaIndex = iconPath!.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = iconPath!.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child:
              Icon(Icons.quiz_rounded, size: 28, color: FolderTheme.accent),
            ),
          );
        }
      } catch (_) {}
    }

    // Fallback: URL-based icon (legacy)
    final url = iconPath!.startsWith('http')
        ? iconPath!
        : '${BaseUrl.imageUrl}/$iconPath';
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.quiz_rounded, size: 28, color: FolderTheme.accent),
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: FolderTheme.textSub),
        const SizedBox(width: 3),
        Text(label, style: FolderTheme.cardSubtitle),
      ],
    );
  }
}

// ─── Published Badge ──────────────────────────────────────────────────────────
class _PublishedBadge extends StatelessWidget {
  final bool isPublished;

  const _PublishedBadge({required this.isPublished});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPublished
            ? const Color(0xFF10B981).withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPublished ? 'Published' : 'Draft',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPublished
              ? const Color(0xFF059669)
              : Colors.orange.shade700,
        ),
      ),
    );
  }
}

// ─── Popup Menu ───────────────────────────────────────────────────────────────
class _QuizSetCardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuizSetCardMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: FolderTheme.textSub),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: FolderTheme.accent),
            SizedBox(width: 10),
            Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _QuizSetsEmptyState extends StatelessWidget {
  const _QuizSetsEmptyState();

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
            child: const Icon(Icons.quiz_outlined,
                size: 38, color: FolderTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No quiz sets found', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Create a new quiz set using the button above.',
            style: FolderTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}

// ─── Quiz Set Form Sheet ──────────────────────────────────────────────────────
class QuizSetFormSheet extends StatefulWidget {
  final QuizSetModel? existing;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const QuizSetFormSheet({
    super.key,
    this.existing,
    required this.onSubmit,
  });

  @override
  State<QuizSetFormSheet> createState() => _QuizSetFormSheetState();
}

class _QuizSetFormSheetState extends State<QuizSetFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _passingScore;
  bool _isPublished = false;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
    _duration = TextEditingController(
        text: widget.existing?.durationMinutes?.toString() ?? '');
    _passingScore = TextEditingController(
        text: widget.existing?.passingScore?.toString() ?? '');
    _isPublished = widget.existing?.isPublished ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _passingScore.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'duration_minutes': int.tryParse(_duration.text),
        'passing_score': int.tryParse(_passingScore.text),
        'is_published': _isPublished,
        // NOTE: icon is NOT passed here — it lives in the VM's selectedIconBase64
        // and is captured directly in _showFormSheet's onSubmit callback.
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickIcon() async {
    await context.read<FolderQuizSetsViewModel>().pickIcon();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: FolderTheme.sheetDecoration,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FolderTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: FolderTheme.sheetIconDecoration,
                    child: Icon(
                      _isEditing
                          ? Icons.drive_file_rename_outline_rounded
                          : Icons.quiz_rounded,
                      color: FolderTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Quiz Set' : 'New Quiz Set',
                    style: FolderTheme.sheetTitle,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Icon picker
              Consumer<FolderQuizSetsViewModel>(
                builder: (_, vm, __) {
                  // Newly picked bytes take priority for preview
                  final Uint8List? previewBytes = vm.selectedIconBytes;
                  // Existing icon from server (only shown when no new pick)
                  final String? existingIconPath = widget.existing?.iconPath;

                  return Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickIcon,
                          child: Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                  FolderTheme.accent.withOpacity(0.08),
                                  border: Border.all(
                                    color:
                                    FolderTheme.accent.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  image: _buildPreviewImage(
                                      previewBytes, existingIconPath),
                                ),
                                child: (previewBytes == null &&
                                    (existingIconPath == null ||
                                        existingIconPath.isEmpty))
                                    ? const Icon(Icons.quiz_rounded,
                                    size: 40,
                                    color: FolderTheme.accent)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: FolderTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          previewBytes != null
                              ? 'Tap to change icon'
                              : 'Tap to upload icon',
                          style: FolderTheme.fieldLabel,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Name field
              _FormField(
                controller: _name,
                label: 'Quiz Set Name',
                icon: Icons.quiz_outlined,
              ),
              const SizedBox(height: 14),

              // Description field
              _FormField(
                controller: _description,
                label: 'Description (optional)',
                icon: Icons.description_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              // Duration + passing score row
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _duration,
                      label: 'Duration (min)',
                      icon: Icons.timer_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: _passingScore,
                      label: 'Passing Score (%)',
                      icon: Icons.check_circle_outline_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Published toggle
              Container(
                decoration: FolderTheme.fieldDecoration(),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.publish_rounded,
                        color: FolderTheme.accent, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child:
                      Text('Published', style: FolderTheme.fieldInput),
                    ),
                    Switch(
                      value: _isPublished,
                      onChanged: (v) => setState(() => _isPublished = v),
                      activeColor: FolderTheme.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FolderTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : Text(
                    _isEditing ? 'Save Changes' : 'Create Quiz Set',
                    style: FolderTheme.submitButton,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build preview image for the icon circle ────────────────────────────────
  DecorationImage? _buildPreviewImage(
      Uint8List? pickedBytes, String? existingIconPath) {
    // Newly picked icon bytes take top priority — show immediately
    if (pickedBytes != null) {
      return DecorationImage(
          image: MemoryImage(pickedBytes), fit: BoxFit.cover);
    }

    if (existingIconPath == null || existingIconPath.isEmpty) return null;

    // FIX: Handle "data:image/jpeg;base64,<data>" URI format from server
    if (existingIconPath.startsWith('data:')) {
      try {
        final commaIndex = existingIconPath.indexOf(',');
        if (commaIndex != -1) {
          final bytes =
          base64Decode(existingIconPath.substring(commaIndex + 1));
          return DecorationImage(
              image: MemoryImage(bytes), fit: BoxFit.cover);
        }
      } catch (_) {}
    }

    // Fallback: URL-based icon (legacy)
    final url = existingIconPath.startsWith('http')
        ? existingIconPath
        : '${BaseUrl.imageUrl}/$existingIconPath';
    return DecorationImage(image: NetworkImage(url), fit: BoxFit.cover);
  }
}

// ─── Reusable form field ──────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FolderTheme.fieldDecoration(),
      child: TextField(
        controller: controller,
        style: FolderTheme.fieldInput,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: FolderTheme.fieldLabel,
          prefixIcon: Icon(icon, color: FolderTheme.accent, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}
