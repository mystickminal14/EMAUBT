import 'package:ema_app/model/folder_mode_v2/folder_model_v2.dart';
import 'package:ema_app/screens/folder_comp/files/files_tab.dart';
import 'package:ema_app/screens/folder_comp/files/quiz_set.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FolderDetailScreen extends StatefulWidget {
  final FolderModelv2 folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FolderFilesViewModel()),
        ChangeNotifierProvider(create: (_) => FolderQuizSetsViewModel()),
      ],
      child: Scaffold(
        backgroundColor: FolderTheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FolderDetailHeader(folder: widget.folder),
              _TabBar(controller: _tabController),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    FilesTab(folderId: widget.folder.id!),
                    QuizSetsTab(folderId: widget.folder.id!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _FolderDetailHeader extends StatelessWidget {
  final FolderModelv2 folder;

  const _FolderDetailHeader({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: FolderTheme.textMain, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name ?? '—',
                  style: FolderTheme.screenTitle.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (folder.fileCount != null)
                  Text(
                    '${folder.fileCount} file${folder.fileCount == 1 ? '' : 's'}',
                    style: FolderTheme.screenSubtitle,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Bar ──────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;

  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: BoxDecoration(
        color: FolderTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FolderTheme.border),
        boxShadow: [
          BoxShadow(
            color: FolderTheme.primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: FolderTheme.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: FolderTheme.textSub,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 18),
                SizedBox(width: 8),
                Text('Files'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, size: 18),
                SizedBox(width: 8),
                Text('Quiz Sets'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}