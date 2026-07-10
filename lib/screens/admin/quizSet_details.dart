import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/view_model/folders/quiz_question_view_model.dart';
import 'package:ema_app/model/quiz_question_model.dart';
import 'package:ema_app/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:ema_app/constants/base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chewie/chewie.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Auth Headers Helper
// ─────────────────────────────────────────────────────────────────────────────
Future<Map<String, String>> getAuthHeaders() async {
  final sp = await SharedPreferences.getInstance();
  final session = sp.getString('session');
  final csrf = sp.getString('csrf');

  final headers = <String, String>{};
  if (session != null && session.isNotEmpty) {
    headers['Cookie'] = 'EMA_SESSION=$session';
  }
  if (csrf != null && csrf.isNotEmpty) {
    headers['X-CSRF-Token'] = csrf;
  }
  return headers;
}

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E8F0);
  static const Color accent = Color(0xFF4361EE);
  static const Color accentLight = Color(0xFFEEF1FD);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color text = Color(0xFF0F172A);
  static const Color textSub = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFF5F3FF);

  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static const TextStyle h1 = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: text,
      letterSpacing: -0.5);
  static const TextStyle h2 = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: text,
      letterSpacing: -0.2);
  static const TextStyle label = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: textSub,
      letterSpacing: 0.8);
  static const TextStyle body = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w400, color: text, height: 1.55);
  static const TextStyle bodySmall = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400, color: textSub, height: 1.4);
  static const TextStyle caption = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w500, color: textMuted);

  static InputDecoration input(String hint, {IconData? icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIcon:
        icon != null ? Icon(icon, size: 17, color: textMuted) : null,
        filled: true,
        fillColor: bg,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Media Type Helpers
// ─────────────────────────────────────────────────────────────────────────────
bool _isImagePath(String? path) {
  if (path == null || path.isEmpty) return false;
  final ext = path.split('.').last.toLowerCase();
  return ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext);
}

bool _isAudioPath(String? path) {
  if (path == null || path.isEmpty) return false;
  final ext = path.split('.').last.toLowerCase();
  return ['mp3', 'wav', 'ogg', 'm4a', 'aac'].contains(ext);
}

bool _isVideoPath(String? path) {
  if (path == null || path.isEmpty) return false;
  final ext = path.split('.').last.toLowerCase();
  return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class QuizSetDetailPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;

  const QuizSetDetailPage({
    super.key,
    required this.quizSetId,
    required this.quizSetName,
  });

  @override
  State<QuizSetDetailPage> createState() => _QuizSetDetailPageState();
}

class _QuizSetDetailPageState extends State<QuizSetDetailPage> {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final ScrollController _scrollCtrl;
  late final TextEditingController _searchCtrl;

  DialogRoute<void>? _loadingRoute;

  @override
  void initState() {
    super.initState();

    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewQuizSetQuestionsViewModel>().fetchQuestions(
        context,
        widget.quizSetId,
        refresh: true,
      );
    });
  }

  // ── FIX: Infinite-scroll — trigger when near the BOTTOM ───────────────────
  // BUG WAS: `pixels < maxScrollExtent - 200` fires near the TOP, not bottom.
  // FIX:     `pixels >= maxScrollExtent - 300` fires when 300px from the bottom.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;

    final pos = _scrollCtrl.position;

    // Only trigger when scrolled to within 300px of the bottom
    if (pos.pixels < pos.maxScrollExtent - 300) return;

    final vm = context.read<NewQuizSetQuestionsViewModel>();
    if (vm.isFetchingMore || vm.isLoading || !vm.hasMorePages) return;

    debugPrint(
        '[_onScroll] Triggered → pixels=${pos.pixels.toStringAsFixed(0)} '
            'max=${pos.maxScrollExtent.toStringAsFixed(0)} → fetching next page');

    vm.fetchNextPage(context, widget.quizSetId);
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Loading overlay ────────────────────────────────────────────────────────
  void _showLoading() {
    if (!mounted || _loadingRoute != null) return;
    final nav = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const _LoadingDialog(),
    );
    _loadingRoute = route;
    nav.push(route);
  }

  void _hideLoading() {
    final route = _loadingRoute;
    if (!mounted || route == null) return;
    _loadingRoute = null;
    Navigator.of(context, rootNavigator: true).removeRoute(route);
  }

  // ── File opener ────────────────────────────────────────────────────────────
  Future<void> _openFile(String filePath) async {
    if (filePath.isEmpty) return;
    try {
      final fullUrl = '${BaseUrl.baseUrl}/$filePath';
      debugPrint('[_openFile] Fetching: $fullUrl');
      final headers = await getAuthHeaders();
      final dir = await getTemporaryDirectory();
      final name = filePath.split('/').last;
      final local = File('${dir.path}/$name');
      final res = await http.get(Uri.parse(fullUrl), headers: headers);

      if (res.statusCode == 200) {
        await local.writeAsBytes(res.bodyBytes);
        final result = await OpenFile.open(local.path);
        if (result.type != ResultType.done && mounted) {
          _toast('Could not open: ${result.message}', isError: true);
        }
      } else {
        if (mounted) {
          _toast('Download failed (${res.statusCode})', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _toast('Error: $e', isError: true);
    }
  }

  // ── Toast ──────────────────────────────────────────────────────────────────
  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    Flushbar(
      message: msg,
      backgroundColor: isError ? _T.danger : _T.success,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(_T.r12),
      icon: Icon(
        isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded,
        color: Colors.white,
        size: 20,
      ),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  // ── CRUD entrypoints ───────────────────────────────────────────────────────
  void _startAdd() {
    context.read<NewQuizSetQuestionsViewModel>().clearFields();
    _showQuestionDialog('Add Question', isEdit: false);
  }

  void _startEdit(int index) {
    final vm = context.read<NewQuizSetQuestionsViewModel>();
    final q = vm.questions[index];
    vm.setFields(
      questionText: q.questionText,
      correctAnswer: q.correctAnswer,
      questionType: q.questionType,
      questionWordFormattingJson: q.questionWordFormatting,
      optionalText: q.optionalText,
      optionalWordFormattingJson: q.optionalWordFormatting,
      choiceAText: q.choiceAText,
      choiceBText: q.choiceBText,
      choiceCText: q.choiceCText,
      choiceDText: q.choiceDText,
      choiceAFilePath: q.choiceAFilePath,
      choiceBFilePath: q.choiceBFilePath,
      choiceCFilePath: q.choiceCFilePath,
      choiceDFilePath: q.choiceDFilePath,
    );

    vm.existingQuestionFilePath = q.questionFilePath;
    vm.choices[0].existingFilePath = q.choiceAFilePath;
    vm.choices[1].existingFilePath = q.choiceBFilePath;
    vm.choices[2].existingFilePath = q.choiceCFilePath;
    vm.choices[3].existingFilePath = q.choiceDFilePath;

    _showQuestionDialog('Edit Question', isEdit: true, questionId: q.id);
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(
        onConfirm: () async {
          if (mounted) Navigator.of(context).pop();
          _showLoading();
          try {
            final vm = context.read<NewQuizSetQuestionsViewModel>();
            await vm.deleteQuestion(
                context, vm.questions[index], widget.quizSetId);
          } finally {
            _hideLoading();
          }
        },
      ),
    );
  }

  void _showQuestionDialog(String title,
      {required bool isEdit, int? questionId}) {
    final vm = context.read<NewQuizSetQuestionsViewModel>();

    final questionCtrl =
    TextEditingController(text: vm.questionText ?? '');
    final optionalCtrl =
    TextEditingController(text: vm.optionalText ?? '');
    final choiceCtrls = List.generate(
      4,
          (i) => TextEditingController(text: vm.choices[i].text ?? ''),
    );

    if (vm.correctAnswer == null || vm.correctAnswer!.isEmpty) {
      vm.correctAnswer = 'A';
    }
    if (vm.questionType == null || vm.questionType!.isEmpty) {
      vm.questionType = 'Reading';
    }

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDs) => _QuestionDialog(
          title: title,
          vm: vm,
          questionCtrl: questionCtrl,
          optionalCtrl: optionalCtrl,
          choiceCtrls: choiceCtrls,
          setDs: setDs,
          onCancel: () => Navigator.of(ctx).pop(),
          onSave: () async {
            final hasQuestionText = questionCtrl.text.trim().isNotEmpty;
            final hasQuestionFile = vm.selectedQuestionFileBytes != null;
            if (!hasQuestionText && !hasQuestionFile) {
              _toast('Question must have text or a file', isError: true);
              return;
            }
            if (vm.correctAnswer == null || vm.correctAnswer!.isEmpty) {
              _toast('Please select the correct answer', isError: true);
              return;
            }
            if (!mounted) return;

            _showLoading();
            bool success = false;
            try {
              if (isEdit && questionId != null) {
                final q =
                vm.questions.firstWhere((q) => q.id == questionId);
                await vm.editQuestion(context, q, widget.quizSetId);
              } else {
                await vm.addQuestion(context, widget.quizSetId);
              }
              success = true;
            } finally {
              _hideLoading();
            }

            if (success) {
              vm.clearFields();
              questionCtrl.clear();
              optionalCtrl.clear();
              for (final c in choiceCtrls) {
                c.clear();
              }
            }
          },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
      decoration: const BoxDecoration(
        color: _T.surface,
        border: Border(bottom: BorderSide(color: _T.border)),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.quizSetName,
                  style: _T.h1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<NewQuizSetQuestionsViewModel>(
                  builder: (_, vm, __) => Text(
                    '${vm.totalQuestions} question${vm.totalQuestions == 1 ? '' : 's'} total',
                    style: _T.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Consumer<NewQuizSetQuestionsViewModel>(
            builder: (_, vm, __) => IconButton(
              onPressed: vm.isLoading
                  ? null
                  : () => vm.fetchQuestions(context, widget.quizSetId,
                  refresh: true),
              icon: AnimatedRotation(
                turns: vm.isLoading ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: const Icon(Icons.refresh_rounded,
                    color: _T.textSub, size: 22),
              ),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        decoration: _T.input(
          'Search questions…',
          icon: Icons.search_rounded,
        ).copyWith(
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
              icon: const Icon(Icons.clear_rounded,
                  size: 17, color: _T.textMuted),
              onPressed: () {
                _searchCtrl.clear();
                context
                    .read<NewQuizSetQuestionsViewModel>()
                    .searchQuestions('');
              },
            ),
          ),
        ),
        onChanged: (q) =>
            context.read<NewQuizSetQuestionsViewModel>().searchQuestions(q),
      ),
    );
  }

  // ── Body with ListView + pagination footer ─────────────────────────────────
  Widget _buildBody() {
    return Consumer<NewQuizSetQuestionsViewModel>(
      builder: (_, vm, __) {
        // Full-page loader on first fetch
        if (vm.isLoading && vm.questions.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: _T.accent, strokeWidth: 2.5),
          );
        }

        // Use filtered list when search is active, raw list otherwise
        final list = _searchCtrl.text.isNotEmpty
            ? vm.filteredQuestions
            : vm.questions;

        if (list.isEmpty) return _buildEmpty();

        return NotificationListener<ScrollNotification>(
          // ── FIX: Secondary safety net using NotificationListener ──────────
          // This catches scroll-end events that the ScrollController might miss
          // when the list is short or the content just became scrollable.
          onNotification: (notification) {
            if (notification is ScrollEndNotification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 300) {
                final vm = context.read<NewQuizSetQuestionsViewModel>();
                if (!vm.isFetchingMore && !vm.isLoading && vm.hasMorePages) {
                  vm.fetchNextPage(context, widget.quizSetId);
                }
              }
            }
            return false; // don't absorb the notification
          },
          child: ResponsiveCenter(
            tabletMaxWidth: 700,
            desktopMaxWidth: 860,
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              // +1 for the footer loader / end-of-list indicator
              itemCount: list.length + 1,
              itemBuilder: (_, i) {
                // Footer item
                if (i == list.length) {
                  return _buildPaginationFooter(vm);
                }

                final q = list[i];
                final actualIdx = vm.questions.indexOf(q);
                return _QuestionCard(
                  question: q,
                  index: actualIdx,
                  onEdit: () => _startEdit(actualIdx),
                  onDelete: () => _confirmDelete(actualIdx),
                  onOpenFile: _openFile,
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── Pagination footer ──────────────────────────────────────────────────────
  Widget _buildPaginationFooter(NewQuizSetQuestionsViewModel vm) {
    if (vm.isFetchingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: _T.accent, strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (!vm.hasMorePages && vm.questions.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'All ${vm.totalQuestions} question${vm.totalQuestions == 1 ? '' : 's'} loaded',
            style: _T.caption,
          ),
        ),
      );
    }

    // Still has more pages but not currently fetching — show a "load more"
    // button as a fallback in case scroll detection misses the trigger
    if (vm.hasMorePages && vm.questions.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: () => vm.fetchNextPage(context, widget.quizSetId),
            icon: const Icon(Icons.expand_more_rounded,
                size: 18, color: _T.accent),
            label: const Text('Load more',
                style: TextStyle(
                    color: _T.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ),
      );
    }

    return const SizedBox(height: 20);
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: _T.accentLight, shape: BoxShape.circle),
            child:
            const Icon(Icons.quiz_outlined, size: 34, color: _T.accent),
          ),
          const SizedBox(height: 16),
          const Text('No questions yet', style: _T.h2),
          const SizedBox(height: 6),
          const Text('Tap + to add your first question',
              style: _T.bodySmall),
          const SizedBox(height: 24),
          _PillButton(
              label: 'Add Question',
              icon: Icons.add_rounded,
              onTap: _startAdd),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _startAdd,
      backgroundColor: _T.accent,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      label: const Text(
        'Add Question',
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.r16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                  AlwaysStoppedAnimation(_T.accent)),
            ),
            SizedBox(width: 16),
            Text('Processing…',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _T.text)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm Delete Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDeleteDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ConfirmDeleteDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_T.r20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: _T.dangerLight,
                  borderRadius: BorderRadius.circular(_T.r12)),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _T.danger, size: 22),
            ),
            const SizedBox(height: 16),
            const Text('Delete Question', style: _T.h2),
            const SizedBox(height: 6),
            const Text(
                'This action cannot be undone. The question will be permanently removed.',
                style: _T.bodySmall),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _T.textSub,
                      side: const BorderSide(color: _T.border),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(_T.r12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(_T.r12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionDialog extends StatelessWidget {
  final String title;
  final NewQuizSetQuestionsViewModel vm;
  final TextEditingController questionCtrl;
  final TextEditingController optionalCtrl;
  final List<TextEditingController> choiceCtrls;
  final StateSetter setDs;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _QuestionDialog({
    required this.title,
    required this.vm,
    required this.questionCtrl,
    required this.optionalCtrl,
    required this.choiceCtrls,
    required this.setDs,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hasQuestionText = questionCtrl.text.trim().isNotEmpty;
    final hasQuestionFile = vm.selectedQuestionFileBytes != null;
    final questionValid = hasQuestionText || hasQuestionFile;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Container(
        constraints:
        const BoxConstraints(maxWidth: 620, maxHeight: 860),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.r20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 40,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _T.border))),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _T.accentLight,
                        borderRadius:
                        BorderRadius.circular(_T.r8)),
                    child: const Icon(Icons.quiz_rounded,
                        color: _T.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: _T.h2),
                  const Spacer(),
                  _IconBtn(
                      icon: Icons.close_rounded, onTap: onCancel),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question section
                    Row(
                      children: [
                        _FieldLabel('QUESTION'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: questionValid
                                ? _T.successLight
                                : _T.warningLight,
                            borderRadius:
                            BorderRadius.circular(4),
                            border: Border.all(
                              color: questionValid
                                  ? _T.success.withOpacity(0.4)
                                  : _T.warning.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            questionValid
                                ? '✓ Ready'
                                : 'Text or File required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: questionValid
                                  ? _T.success
                                  : _T.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _InfoBanner(
                      text: 'Enter question text, attach a file, or both.',
                      color: _T.accent,
                      bgColor: _T.accentLight,
                      icon: Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: questionCtrl,
                      decoration: _T.input(
                        hasQuestionFile
                            ? 'Question text (optional — file attached)'
                            : 'Enter your question… (required if no file)',
                        icon: Icons.help_outline_rounded,
                      ),
                      maxLines: 3,
                      style: const TextStyle(
                          fontSize: 14, color: _T.text),
                      onChanged: (t) {
                        vm.questionText = t;
                        setDs(() {});
                      },
                    ),

                    if (questionCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _IndexRangeFormatterWidget(
                        label: 'FORMAT QUESTION',
                        text: questionCtrl.text,
                        formatting: vm.questionWordFormatting,
                        onChanged: (v) =>
                            setDs(() => vm.questionWordFormatting = v),
                        onClear: () =>
                            setDs(() => vm.clearQuestionFormatting()),
                      ),
                    ],

                    const SizedBox(height: 14),
                    _FieldLabel('QUESTION FILE'),
                    const SizedBox(height: 8),
                    _MediaDropZone(
                      hasFile: vm.selectedQuestionFileBytes != null,
                      fileName: vm.selectedQuestionFileName,
                      mimeType: vm.selectedQuestionFileMimeType,
                      onPickImage: () async {
                        await vm.pickQuestionFile(fileType: 'image');
                        setDs(() {});
                      },
                      onPickAudio: () async {
                        await vm.pickQuestionFile(fileType: 'audio');
                        setDs(() {});
                      },
                      onPickVideo: () async {
                        await vm.pickQuestionFile(fileType: 'video');
                        setDs(() {});
                      },
                      onClear: () {
                        vm.clearQuestionFile();
                        setDs(() {});
                      },
                    ),
                    _FilePreview(
                      bytes: vm.selectedQuestionFileBytes,
                      mimeType: vm.selectedQuestionFileMimeType,
                      fileName: vm.selectedQuestionFileName,
                      existingPath: vm.existingQuestionFilePath, // ← add this
                    ),

                    const SizedBox(height: 20),
                    const _Divider(),
                    const SizedBox(height: 20),

                    // Optional passage
                    _FieldLabel('PASSAGE / OPTIONAL TEXT'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionalCtrl,
                      decoration: _T.input(
                          'Enter optional passage or note…',
                          icon: Icons.notes_rounded),
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 14, color: _T.text),
                      onChanged: (t) {
                        vm.optionalText = t;
                        setDs(() {});
                      },
                    ),

                    if (optionalCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _IndexRangeFormatterWidget(
                        label: 'FORMAT PASSAGE',
                        text: optionalCtrl.text,
                        formatting: vm.optionalWordFormatting,
                        onChanged: (v) =>
                            setDs(() => vm.optionalWordFormatting = v),
                        onClear: () =>
                            setDs(() => vm.clearOptionalFormatting()),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const _Divider(),
                    const SizedBox(height: 20),

                    // Choices
                    _FieldLabel('ANSWER CHOICES *'),
                    const SizedBox(height: 4),
                    _InfoBanner(
                      text: 'Each choice needs text, a file, or both.',
                      color: _T.warning,
                      bgColor: _T.warningLight,
                      icon: Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 12),

                    for (int i = 0; i < 4; i++) ...[
                      _ChoiceEditor(
                        index: i,
                        textController: choiceCtrls[i],
                        choice: vm.choices[i],
                        onTextChanged: (t) {
                          vm.choices[i].text =
                          t.trim().isEmpty ? null : t;
                        },
                        onPickImage: () async {
                          await vm.pickChoiceFile(i,
                              fileType: 'image');
                          setDs(() {});
                        },
                        onPickAudio: () async {
                          await vm.pickChoiceFile(i,
                              fileType: 'audio');
                          setDs(() {});
                        },
                        onPickVideo: () async {
                          await vm.pickChoiceFile(i,
                              fileType: 'video');
                          setDs(() {});
                        },
                        onClearFile: () {
                          vm.clearChoiceFile(i);
                          setDs(() {});
                        },
                      ),
                      _FilePreview(
                        bytes: vm.choices[i].fileBytes,           // newly picked bytes (null in edit mode)
                        mimeType: vm.choices[i].mimeType,
                        fileName: vm.choices[i].fileName,
                        existingPath: vm.choices[i].existingFilePath, // ← server path shown in edit mode
                      ),
                      if (i < 3) const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 20),
                    const _Divider(),
                    const SizedBox(height: 20),

                    // Correct answer + type
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('CORRECT ANSWER *'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: vm.correctAnswer ?? 'A',
                                decoration: _T.input(''),
                                style: const TextStyle(
                                    fontSize: 14, color: _T.text),
                                dropdownColor: _T.surface,
                                items: ['A', 'B', 'C', 'D']
                                    .map((v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('Answer $v')))
                                    .toList(),
                                onChanged: (v) =>
                                    setDs(() => vm.correctAnswer = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('QUESTION TYPE'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: (vm.questionType
                                    ?.toLowerCase() ==
                                    'listening')
                                    ? 'Listening'
                                    : 'Reading',
                                onChanged: (v) => setDs(() =>
                                vm.questionType =
                                    v?.toLowerCase()),
                                decoration: _T.input(''),
                                style: const TextStyle(
                                    fontSize: 14, color: _T.text),
                                dropdownColor: _T.surface,
                                items: ['Reading', 'Listening']
                                    .map((v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v)))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                  border:
                  Border(top: BorderSide(color: _T.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _T.textSub,
                      side: const BorderSide(color: _T.border),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(_T.r12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check_rounded,
                        size: 17, color: Colors.white),
                    label: const Text('Save Question',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(_T.r12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Updated _FilePreview ──────────────────────────────────────────
class _FilePreview extends StatelessWidget {
  final Uint8List? bytes;
  final String? mimeType;
  final String? fileName;
  final String? existingPath;

  const _FilePreview({this.bytes, this.mimeType, this.fileName, this.existingPath});

  bool get _isImage => mimeType?.startsWith('image/') ?? false;
  bool get _isAudio => mimeType?.startsWith('audio/') ?? false;
  bool get _isVideo => mimeType?.startsWith('video/') ?? false;

  @override
  Widget build(BuildContext context) {
    // ── Newly picked file (bytes) ──────────────────────────────
    if (bytes != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _isImage
            ? _buildBytesImage()
            : _isAudio
            ? _BytesAudioPlayer(bytes: bytes!, fileName: fileName ?? 'audio')
            : _isVideo
            ? _BytesVideoPlayer(bytes: bytes!, fileName: fileName ?? 'video')
            : const SizedBox.shrink(),
      );
    }

    // ── Existing server file (edit mode) ───────────────────────
    if (existingPath != null && existingPath!.isNotEmpty) {
      final url = '${BaseUrl.imageUrl}/$existingPath';
      final path = existingPath!;
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _isImagePath(path)
            ? _buildNetworkImage(url)
            : _isAudioPath(path)
            ? _AudioPlayer(url: url, fileName: path.split('/').last)
            : _isVideoPath(path)
            ? _VideoPlayerWidget(url: url)
            : const SizedBox.shrink(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBytesImage() {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(_T.r8),
        child: Image.memory(bytes!, width: double.infinity, height: 180, fit: BoxFit.cover),
      ),
      Positioned(top: 8, right: 8, child: _badge('Preview')),
    ]);
  }

  Widget _buildNetworkImage(String url) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(_T.r8),
        child: Image.network(url,
            width: double.infinity, height: 180, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Text('Image unavailable', style: _T.caption)),
      ),
      Positioned(top: 8, right: 8, child: _badge('Current')),
    ]);
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.image_rounded, color: Colors.white, size: 12),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    ]),
  );
}
class _BytesAudioPlayer extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  const _BytesAudioPlayer({required this.bytes, required this.fileName});

  @override
  State<_BytesAudioPlayer> createState() => _BytesAudioPlayerState();
}

class _BytesAudioPlayerState extends State<_BytesAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) => mounted ? setState(() => _duration = d) : null);
    _player.onPositionChanged.listen((p) => mounted ? setState(() => _position = p) : null);
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen(
            (_) => mounted ? setState(() => _position = Duration.zero) : null);
    _writeToTemp();
  }

  Future<void> _writeToTemp() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.fileName}');
    await file.writeAsBytes(widget.bytes);
    if (mounted) setState(() => _localPath = file.path);
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _togglePlay() async {
    if (_localPath == null) return;
    if (_isPlaying) { await _player.pause(); return; }
    await _player.play(DeviceFileSource(_localPath!));
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
          '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.purpleLight,
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: _T.purple.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.audiotrack_rounded, size: 14, color: _T.purple),
          const SizedBox(width: 6),
          Expanded(
            child: Text(widget.fileName,
                style: const TextStyle(fontSize: 12, color: _T.purple, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          GestureDetector(
            onTap: _localPath == null ? null : _togglePlay,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _localPath == null ? _T.textMuted : _T.purple,
                shape: BoxShape.circle,
                boxShadow: _localPath == null ? [] : [
                  BoxShadow(color: _T.purple.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: _localPath == null
                  ? const Padding(padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: _T.purple,
                inactiveTrackColor: _T.purple.withOpacity(0.18),
                thumbColor: _T.purple,
                overlayColor: _T.purple.withOpacity(0.12),
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                onChanged: (v) async => await _player.seek(Duration(seconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_fmt(_position), style: _T.caption),
                Text(_fmt(_duration), style: _T.caption),
              ]),
            ),
          ])),
        ]),
      ]),
    );
  }
}
class _BytesVideoPlayer extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  const _BytesVideoPlayer({required this.bytes, required this.fileName});

  @override
  State<_BytesVideoPlayer> createState() => _BytesVideoPlayerState();
}

class _BytesVideoPlayerState extends State<_BytesVideoPlayer> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _playerReady = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);

      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();

      final chewie = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: ctrl.value.aspectRatio,
      );

      if (mounted) {
        setState(() {
          _videoCtrl = ctrl;
          _chewieCtrl = chewie;
          _playerReady = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('[_BytesVideoPlayer] Error: $e');
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(_T.r12),
        ),
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 32, height: 32,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
          SizedBox(height: 8),
          Text('Preparing video…',
              style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
        ])),
      );
    }

    if (_playerReady && _chewieCtrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_T.r12),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: Chewie(controller: _chewieCtrl!),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Question Card
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  final QuizQuestionModel question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(String) onOpenFile;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenFile,
  });

  String _choiceText(String l) {
    switch (l) {
      case 'A':
        return question.choiceAText ?? '';
      case 'B':
        return question.choiceBText ?? '';
      case 'C':
        return question.choiceCText ?? '';
      case 'D':
        return question.choiceDText ?? '';
      default:
        return '';
    }
  }

  String _choiceFile(String l) {
    switch (l) {
      case 'A':
        return question.choiceAFilePath ?? '';
      case 'B':
        return question.choiceBFilePath ?? '';
      case 'C':
        return question.choiceCFilePath ?? '';
      case 'D':
        return question.choiceDFilePath ?? '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final qFmt = question.parsedQuestionFormatting;
    final optFmt = question.parsedOptionalFormatting;
    final isListening =
        question.questionType?.toLowerCase() == 'listening';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(_T.r16),
        border: Border.all(color: _T.border),
        boxShadow: _T.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: const BoxDecoration(
                border:
                Border(bottom: BorderSide(color: _T.border))),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _T.accentLight,
                      borderRadius:
                      BorderRadius.circular(_T.r8)),
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _T.accent)),
                ),
                const SizedBox(width: 10),
                if (question.questionType?.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isListening
                          ? const Color(0xFFEFF6FF)
                          : _T.accentLight,
                      borderRadius:
                      BorderRadius.circular(_T.r4 + 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isListening
                                ? Icons.headphones_rounded
                                : Icons.menu_book_rounded,
                            size: 11,
                            color: _T.accent),
                        const SizedBox(width: 4),
                        Text(question.questionType!,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _T.accent)),
                      ],
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: _T.textMuted, size: 20),
                  color: _T.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(_T.r12),
                    side: const BorderSide(color: _T.border),
                  ),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: const [
                        Icon(Icons.edit_rounded,
                            size: 16, color: _T.accent),
                        SizedBox(width: 10),
                        Text('Edit',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: const [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: _T.danger),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _T.danger)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.questionText?.isNotEmpty == true)
                  _FormattedText(
                    text: question.questionText!,
                    formatting: qFmt,
                    style: _T.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _T.text,
                        fontSize: 15),
                  ),

                if (question.questionFilePath?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 10),
                  _MediaPreview(
                    path: question.questionFilePath!,
                    onOpenFile: onOpenFile,
                  ),
                ],

                if (question.optionalText?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius:
                      BorderRadius.circular(_T.r12),
                      border: Border.all(color: _T.border),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.notes_rounded,
                              size: 13, color: _T.textMuted),
                          SizedBox(width: 5),
                          Text('Passage', style: _T.caption),
                        ]),
                        const SizedBox(height: 6),
                        _FormattedText(
                          text: question.optionalText!,
                          formatting: optFmt,
                          style: _T.body.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                for (final letter in ['A', 'B', 'C', 'D']) ...[
                  Builder(builder: (_) {
                    final txt = _choiceText(letter);
                    final file = _choiceFile(letter);
                    if (txt.isEmpty && file.isEmpty) {
                      return const SizedBox();
                    }
                    final isCorrect =
                        question.correctAnswer == letter;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? _T.successLight
                            : _T.bg,
                        borderRadius:
                        BorderRadius.circular(_T.r12),
                        border: Border.all(
                            color: isCorrect
                                ? _T.success.withOpacity(0.35)
                                : _T.border),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? _T.success.withOpacity(0.15)
                                  : _T.accentLight,
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isCorrect
                                    ? _T.success
                                    : _T.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                if (txt.isNotEmpty)
                                  Text(
                                    txt,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _T.text,
                                      fontWeight: isCorrect
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                if (txt.isNotEmpty &&
                                    file.isNotEmpty)
                                  const SizedBox(height: 6),
                                if (file.isNotEmpty)
                                  _MediaPreview(
                                    path: file,
                                    compact: true,
                                    onOpenFile: onOpenFile,
                                  ),
                              ],
                            ),
                          ),
                          if (isCorrect)
                            const Padding(
                              padding: EdgeInsets.only(
                                  left: 6, top: 2),
                              child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: _T.success),
                            ),
                        ],
                      ),
                    );
                  }),
                ],

                if (question.correctAnswer?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _T.successLight,
                      borderRadius:
                      BorderRadius.circular(_T.r8),
                      border: Border.all(
                          color:
                          _T.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: _T.success),
                        const SizedBox(width: 6),
                        Text(
                          'Correct: ${question.correctAnswer}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _T.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media Preview
// ─────────────────────────────────────────────────────────────────────────────
class _MediaPreview extends StatelessWidget {
  final String path;
  final bool compact;
  final Future<void> Function(String) onOpenFile;

  const _MediaPreview({
    required this.path,
    required this.onOpenFile,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final resUrl = '${BaseUrl.imageUrl}/$path';

    if (_isImagePath(path)) {
      return _ImagePreview(url: resUrl, compact: compact);
    }
    if (_isAudioPath(path)) {
      return _AudioPlayer(
          url: resUrl,
          fileName: path.split('/').last,
          compact: compact);
    }
    if (_isVideoPath(path)) {
      return _VideoPlayerWidget(url: resUrl, compact: compact);
    }
    return _GenericFileChip(path: path, onOpen: () => onOpenFile(path));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Preview
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final String url;
  final bool compact;

  const _ImagePreview({required this.url, this.compact = false});

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                          'Image unavailable',
                          style:
                          TextStyle(color: Colors.white))),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_T.r8),
            child: Image.network(
              url,
              height: compact ? 70 : 140,
              width: compact ? 100 : double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, error, __) =>
              const Text('Image unavailable', style: _T.caption),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.zoom_out_map_rounded,
                  size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Player
// ─────────────────────────────────────────────────────────────────────────────
class _AudioPlayer extends StatefulWidget {
  final String url;
  final String fileName;
  final bool compact;

  const _AudioPlayer(
      {required this.url,
        required this.fileName,
        this.compact = false});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged
        .listen((d) => mounted ? setState(() => _duration = d) : null);
    _player.onPositionChanged
        .listen((p) => mounted ? setState(() => _position = p) : null);
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onPlayerComplete.listen(
            (_) => mounted ? setState(() => _position = Duration.zero) : null);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_localPath == null) {
        final headers = await getAuthHeaders();
        final res = await http
            .get(Uri.parse(widget.url), headers: headers)
            .timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) return;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.fileName}');
        await file.writeAsBytes(res.bodyBytes);
        _localPath = file.path;
      }
      await _player.play(DeviceFileSource(_localPath!));
    } catch (e) {
      debugPrint('[_AudioPlayer] Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    if (widget.compact) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _T.purpleLight,
          borderRadius: BorderRadius.circular(_T.r8),
          border: Border.all(color: _T.purple.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: _T.purple, shape: BoxShape.circle),
                child: _isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 16,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.fileName,
                      style: const TextStyle(
                          fontSize: 11,
                          color: _T.purple,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor:
                      _T.purple.withOpacity(0.15),
                      valueColor:
                      const AlwaysStoppedAnimation(_T.purple),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.purpleLight,
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: _T.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.audiotrack_rounded,
                  size: 14, color: _T.purple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.fileName,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _T.purple,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _T.purple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _T.purple.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: _isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white),
                  )
                      : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape:
                        const RoundSliderOverlayShape(
                            overlayRadius: 12),
                        activeTrackColor: _T.purple,
                        inactiveTrackColor:
                        _T.purple.withOpacity(0.18),
                        thumbColor: _T.purple,
                        overlayColor:
                        _T.purple.withOpacity(0.12),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0,
                        onChanged: (v) async {
                          await _player.seek(
                              Duration(seconds: v.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_position),
                              style: _T.caption),
                          Text(_fmt(_duration),
                              style: _T.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video Player
// ─────────────────────────────────────────────────────────────────────────────
class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  final bool compact;

  const _VideoPlayerWidget(
      {required this.url, this.compact = false});

  @override
  State<_VideoPlayerWidget> createState() =>
      _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _playerReady = false;
  bool _expanded = false;
  bool _isInitializing = false;
  String? _localPath;

  Future<void> _initPlayer() async {
    if (_isInitializing || _playerReady) return;
    setState(() => _isInitializing = true);

    try {
      if (_localPath == null) {
        final headers = await getAuthHeaders();
        final res = await http
            .get(Uri.parse(widget.url), headers: headers)
            .timeout(const Duration(seconds: 120));
        if (res.statusCode != 200) {
          if (mounted) setState(() => _isInitializing = false);
          return;
        }
        final dir = await getTemporaryDirectory();
        final fileName =
            widget.url.split('/').last.split('?').first;
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(res.bodyBytes);
        _localPath = file.path;
      }

      final ctrl = VideoPlayerController.file(File(_localPath!));
      await ctrl.initialize();

      final chewie = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: ctrl.value.aspectRatio,
      );

      if (mounted) {
        setState(() {
          _videoCtrl = ctrl;
          _chewieCtrl = chewie;
          _playerReady = true;
          _expanded = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('[_VideoPlayerWidget] Error: $e');
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 90.0 : 200.0;
    final borderRadius = BorderRadius.circular(_T.r12);

    if (_expanded && _playerReady && _chewieCtrl != null) {
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          barrierColor: Colors.black,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(child: Chewie(controller: _chewieCtrl!)),
                Positioned(
                  top: 40,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            height: widget.compact ? 120 : 220,
            width: double.infinity,
            child: Chewie(controller: _chewieCtrl!),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _initPlayer,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: borderRadius,
          border:
          Border.all(color: _T.danger.withOpacity(0.2)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.videocam_outlined,
                size: widget.compact ? 32 : 56,
                color: Colors.white.withOpacity(0.06)),
            if (_isInitializing)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                  SizedBox(height: 8),
                  Text('Downloading…',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500)),
                ],
              )
            else
              Container(
                width: widget.compact ? 36 : 56,
                height: widget.compact ? 36 : 56,
                decoration: BoxDecoration(
                  color: _T.danger,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _T.danger.withOpacity(0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: widget.compact ? 20 : 30),
              ),
            if (!widget.compact)
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded,
                        size: 12, color: Colors.white54),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                          widget.url
                              .split('/')
                              .last
                              .split('?')
                              .first,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic file chip
// ─────────────────────────────────────────────────────────────────────────────
class _GenericFileChip extends StatelessWidget {
  final String path;
  final VoidCallback onOpen;

  const _GenericFileChip(
      {required this.path, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _T.accentLight,
          borderRadius: BorderRadius.circular(_T.r8),
          border: Border.all(color: _T.accent.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 15, color: _T.accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(path.split('/').last,
                style: const TextStyle(
                    fontSize: 12,
                    color: _T.accent,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.open_in_new_rounded,
              size: 13, color: _T.accent),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Index-Range Formatter Widget
// ─────────────────────────────────────────────────────────────────────────────
class _IndexRangeFormatterWidget extends StatelessWidget {
  final String label;
  final String text;
  final WordFormattingRanges formatting;
  final ValueChanged<WordFormattingRanges> onChanged;
  final VoidCallback onClear;

  const _IndexRangeFormatterWidget({
    required this.label,
    required this.text,
    required this.formatting,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox();

    final tokens = <_Token>[];
    final regex = RegExp(r'\S+');
    for (final m in regex.allMatches(text)) {
      tokens.add(_Token(m.group(0)!, m.start, m.end));
    }
    if (tokens.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.format_color_text_rounded,
                size: 14, color: _T.accent),
            const SizedBox(width: 6),
            Text(label, style: _T.label),
            const Spacer(),
            if (!formatting.isEmpty)
              GestureDetector(
                onTap: onClear,
                child: const Text('Clear all',
                    style: TextStyle(
                        fontSize: 11,
                        color: _T.accent,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: const [
            _FmtLegend(
                icon: Icons.format_bold,
                label: 'Tap = Bold',
                color: _T.text),
            _FmtLegend(
                icon: Icons.format_underlined,
                label: 'Long press = Underline',
                color: _T.accent),
            _FmtLegend(
                icon: Icons.format_italic,
                label: 'Double tap = Italic',
                color: _T.purple),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tokens.map((token) {
              final range =
              TextRange(start: token.start, end: token.end);
              final isBold = formatting.bold.contains(range);
              final isUnder =
              formatting.underline.contains(range);
              final isItalic =
              formatting.italic.contains(range);

              Color chipBg = Colors.white;
              Color chipBorder = _T.border;
              Color textColor = _T.text;

              if (isBold && isItalic) {
                chipBg = _T.text.withOpacity(0.06);
                chipBorder = _T.purple.withOpacity(0.4);
              } else if (isBold) {
                chipBg = _T.text.withOpacity(0.06);
                chipBorder = _T.text.withOpacity(0.25);
              } else if (isUnder) {
                chipBg = _T.accentLight;
                chipBorder = _T.accent.withOpacity(0.35);
                textColor = _T.accent;
              } else if (isItalic) {
                chipBg = _T.purpleLight;
                chipBorder = _T.purple.withOpacity(0.35);
                textColor = _T.purple;
              }

              return GestureDetector(
                onTap: () =>
                    onChanged(formatting.toggleBold(range)),
                onLongPress: () =>
                    onChanged(formatting.toggleUnderline(range)),
                onDoubleTap: () =>
                    onChanged(formatting.toggleItalic(range)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius:
                    BorderRadius.circular(_T.r8),
                    border: Border.all(color: chipBorder),
                  ),
                  child: Text(
                    token.word,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isBold
                          ? FontWeight.w800
                          : FontWeight.normal,
                      fontStyle: isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      decoration: isUnder
                          ? TextDecoration.underline
                          : null,
                      decorationThickness: 2,
                      color: textColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Token {
  final String word;
  final int start;
  final int end;
  const _Token(this.word, this.start, this.end);
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatted Text
// ─────────────────────────────────────────────────────────────────────────────
class _FormattedText extends StatelessWidget {
  final String text;
  final WordFormattingRanges formatting;
  final TextStyle style;

  const _FormattedText(
      {required this.text,
        required this.formatting,
        required this.style});

  @override
  Widget build(BuildContext context) {
    if (formatting.isEmpty) return Text(text, style: style);

    final spans = <TextSpan>[];
    for (int i = 0; i < text.length; i++) {
      spans.add(TextSpan(
        text: text[i],
        style: style.copyWith(
          fontWeight: formatting.isBoldAt(i)
              ? FontWeight.w800
              : style.fontWeight,
          fontStyle: formatting.isItalicAt(i)
              ? FontStyle.italic
              : FontStyle.normal,
          decoration: formatting.isUnderlineAt(i)
              ? TextDecoration.underline
              : null,
          decorationThickness: 2,
        ),
      ));
    }
    return RichText(text: TextSpan(children: _merge(spans)));
  }

  List<TextSpan> _merge(List<TextSpan> spans) {
    if (spans.isEmpty) return spans;
    final out = <TextSpan>[];
    var cur = spans.first;
    for (int i = 1; i < spans.length; i++) {
      final n = spans[i];
      if (_eq(cur.style, n.style)) {
        cur = TextSpan(
            text: (cur.text ?? '') + (n.text ?? ''),
            style: cur.style);
      } else {
        out.add(cur);
        cur = n;
      }
    }
    out.add(cur);
    return out;
  }

  bool _eq(TextStyle? a, TextStyle? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.fontWeight == b.fontWeight &&
        a.fontStyle == b.fontStyle &&
        a.decoration == b.decoration;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media Drop Zone
// ─────────────────────────────────────────────────────────────────────────────
class _MediaDropZone extends StatelessWidget {
  final bool hasFile;
  final String? fileName;
  final String? mimeType;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onPickVideo;
  final VoidCallback onClear;

  const _MediaDropZone({
    required this.hasFile,
    this.fileName,
    this.mimeType,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onPickVideo,
    required this.onClear,
  });

  IconData get _icon {
    if (mimeType == null) return Icons.attach_file_rounded;
    if (mimeType!.startsWith('image')) return Icons.image_outlined;
    if (mimeType!.startsWith('audio'))
      return Icons.audiotrack_outlined;
    if (mimeType!.startsWith('video'))
      return Icons.videocam_outlined;
    return Icons.attach_file_rounded;
  }

  Color get _color {
    if (mimeType == null) return _T.accent;
    if (mimeType!.startsWith('image')) return _T.accent;
    if (mimeType!.startsWith('audio')) return _T.purple;
    if (mimeType!.startsWith('video')) return _T.danger;
    return _T.accent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: _MediaBtn(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    color: _T.accent,
                    onTap: onPickImage)),
            const SizedBox(width: 8),
            Expanded(
                child: _MediaBtn(
                    icon: Icons.audiotrack_outlined,
                    label: 'Audio',
                    color: _T.purple,
                    onTap: onPickAudio)),
            const SizedBox(width: 8),
            Expanded(
                child: _MediaBtn(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: _T.danger,
                    onTap: onPickVideo)),
          ]),
          if (hasFile && fileName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(_T.r8),
                border: Border.all(
                    color: _color.withOpacity(0.25)),
              ),
              child: Row(children: [
                Icon(_icon, size: 15, color: _color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(fileName!,
                      style: TextStyle(
                          fontSize: 12,
                          color: _color,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded,
                        size: 15, color: _color)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media Button
// ─────────────────────────────────────────────────────────────────────────────
class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaBtn(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(_T.r8),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice Editor
// ─────────────────────────────────────────────────────────────────────────────
class _ChoiceEditor extends StatelessWidget {
  final int index;
  final TextEditingController textController;
  final QuizChoiceInput choice;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onPickVideo;
  final VoidCallback onClearFile;

  const _ChoiceEditor({
    required this.index,
    required this.textController,
    required this.choice,
    required this.onTextChanged,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onPickVideo,
    required this.onClearFile,
  });

  Color get _fileColor {
    if (choice.mimeType == null) return _T.accent;
    if (choice.mimeType!.startsWith('image')) return _T.accent;
    if (choice.mimeType!.startsWith('audio')) return _T.purple;
    if (choice.mimeType!.startsWith('video')) return _T.danger;
    return _T.accent;
  }

  IconData get _fileIcon {
    if (choice.mimeType == null)
      return Icons.attach_file_rounded;
    if (choice.mimeType!.startsWith('image'))
      return Icons.image_outlined;
    if (choice.mimeType!.startsWith('audio'))
      return Icons.audiotrack_outlined;
    if (choice.mimeType!.startsWith('video'))
      return Icons.videocam_outlined;
    return Icons.attach_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + index);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _T.accentLight,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(letter,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _T.accent)),
            ),
            const SizedBox(width: 8),
            Text('Choice $letter *', style: _T.label),
            const Spacer(),
            if (choice.hasText && choice.hasFile)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _T.successLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _T.success.withOpacity(0.3)),
                ),
                child: const Text('Text + File',
                    style: TextStyle(
                        fontSize: 10,
                        color: _T.success,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: textController,
            decoration: _T.input('Choice $letter text…'),
            style:
            const TextStyle(fontSize: 13, color: _T.text),
            onChanged: onTextChanged,
          ),
          const SizedBox(height: 10),
          Text('ATTACH FILE (optional)',
              style: _T.label.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _MediaBtn(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    color: _T.accent,
                    onTap: onPickImage)),
            const SizedBox(width: 6),
            Expanded(
                child: _MediaBtn(
                    icon: Icons.audiotrack_outlined,
                    label: 'Audio',
                    color: _T.purple,
                    onTap: onPickAudio)),
            const SizedBox(width: 6),
            Expanded(
                child: _MediaBtn(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: _T.danger,
                    onTap: onPickVideo)),
          ]),
          if (choice.fileName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _fileColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(_T.r8),
                border: Border.all(
                    color: _fileColor.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(_fileIcon,
                      size: 13, color: _fileColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      choice.fileName!.split('/').last,
                      style: TextStyle(
                          fontSize: 11,
                          color: _fileColor,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!choice.hasFile) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                        _fileColor.withOpacity(0.15),
                        borderRadius:
                        BorderRadius.circular(4),
                      ),
                      child: Text('Current',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _fileColor)),
                    ),
                  ],
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onClearFile,
                    child: Icon(Icons.close_rounded,
                        size: 13, color: _fileColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: _T.label);
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(color: _T.border, height: 1);
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _InfoBanner(
      {required this.text,
        required this.color,
        required this.bgColor,
        required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_T.r8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.r8),
          border: Border.all(color: _T.border),
        ),
        child: Icon(icon, size: 16, color: _T.textSub),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PillButton(
      {required this.label,
        required this.icon,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _T.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_T.r12)),
        padding: const EdgeInsets.symmetric(
            horizontal: 22, vertical: 13),
      ),
    );
  }
}

class _FmtLegend extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FmtLegend(
      {required this.icon,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: _T.caption),
    ]);
  }
}