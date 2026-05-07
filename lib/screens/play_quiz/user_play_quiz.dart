import 'package:ema_app/screens/play_quiz/user_quiz_set_new.dart';
import 'package:ema_app/view_model/folders/user_question_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shown when user taps "Open" on a quiz set.
/// Downloads all questions + media, then transitions to the quiz overview.
///
/// FIX: This widget now accepts an already-created [UserQuizViewModel]
/// instead of trying to read one from the provider tree — this avoids the
/// "Failed to start quiz" bug that happened when _openQuizSetNew created a
/// new vm via ChangeNotifierProvider but the page tried to read a different
/// one from context.
class UserQuizLoadPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String fullName;
  final String userEmail;

  const UserQuizLoadPage({
    super.key,
    required this.quizSetId,
    required this.quizSetName,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.fullName,
    required this.userEmail,
  });

  @override
  State<UserQuizLoadPage> createState() => _UserQuizLoadPageState();
}

class _UserQuizLoadPageState extends State<UserQuizLoadPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // FIX: We own the vm here and pass it down explicitly.
  // Previously the vm was created by ChangeNotifierProvider in _openQuizSetNew
  // but then context.read<UserQuizViewModel>() in initState picked up a
  // different (or unregistered) vm, causing startQuizAttempt to fail.
  late final UserQuizViewModel _vm;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // FIX: Create the vm ourselves so we control its lifetime.
    _vm = UserQuizViewModel();
    _vm.addListener(_onVmChange);

    // Start loading immediately — no need to wait for postFrameCallback
    // because _vm is created synchronously above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.loadQuizSet(widget.quizSetId);
    });
  }

  void _onVmChange() {
    if (!mounted) return;
    setState(() {});

    if (_navigating) return;

    if (_vm.status == QuizLoadStatus.ready) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // FIX: Pass _vm via ChangeNotifierProvider.value so that
        // UserQuizOverviewPage and its children all share the SAME instance.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<UserQuizViewModel>.value(
              value: _vm,
              child: UserQuizOverviewPage(
                quizSetId: widget.quizSetId,
                quizSetName: widget.quizSetName,
                folderId: widget.folderId,
                folderName: widget.folderName,
                userIdentifier: widget.userIdentifier,
                isAdmin: widget.isAdmin,
                fullName: widget.fullName,
                userEmail: widget.userEmail,
              ),
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _vm.removeListener(_onVmChange);
    // FIX: Only dispose _vm if we are not navigating away — if we navigated,
    // the provider keeps the vm alive for UserQuizOverviewPage.
    if (!_navigating) {
      _vm.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder on _vm directly (no Consumer needed since we own it)
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final isError = _vm.status == QuizLoadStatus.error;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(
            backgroundColor: Colors.teal[700],
            title: Text(
              widget.quizSetName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    MediaQuery.of(context).padding.top,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child:
                  isError ? _buildError() : _buildProgress(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgress() {
    final isFetching = _vm.status == QuizLoadStatus.fetchingQuestions;
    final isDownloading = _vm.status == QuizLoadStatus.downloadingMedia;

    double progress = 0.0;
    if (isFetching && _vm.totalPages > 0) {
      progress = _vm.fetchProgress * 0.5;
    } else if (isDownloading) {
      progress = 0.5 + _vm.downloadProgress * 0.5;
    } else if (_vm.status == QuizLoadStatus.ready) {
      progress = 1.0;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.teal.withOpacity(0.1),
            ),
            child: Icon(
              isDownloading
                  ? Icons.download_rounded
                  : Icons.quiz_rounded,
              size: 52,
              color: Colors.teal[700],
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text(
          isFetching ? 'Fetching Questions' : 'Downloading Media',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),

        Text(
          _vm.statusMessage,
          textAlign: TextAlign.center,
          style:
          const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 28),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.teal.withOpacity(0.12),
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.teal[600]!),
          ),
        ),
        const SizedBox(height: 12),

        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        const SizedBox(height: 8),

        if (_vm.allQuestions.isNotEmpty)
          Text(
            '${_vm.allQuestions.length} questions fetched',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        if (isDownloading && _vm.totalFilesToDownload > 0)
          Text(
            '${_vm.downloadedFiles}/${_vm.totalFilesToDownload} files',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF94A3B8)),
          ),

        const SizedBox(height: 20),
        const Text(
          'Please keep this screen open',
          style: TextStyle(fontSize: 12, color: Color(0xFFB0BEC5)),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded,
            size: 64, color: Colors.red[400]),
        const SizedBox(height: 20),
        const Text(
          'Something went wrong',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        Text(
          _vm.errorMessage ?? 'Unknown error',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _navigating = false;
                _vm.reset();
                _vm.loadQuizSet(widget.quizSetId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}