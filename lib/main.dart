import 'package:ema_app/screens/admin/admin_quiz_set_detail_page.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/view_model/folders/files_view_model.dart';
import 'package:ema_app/view_model/folders/folder_view_model.dart';
import 'package:ema_app/view_model/folders/quiz_view_model.dart';
import 'package:ema_app/view_model/user_view_model/auth_view_model.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) {
      await _clearCache();
    }
  }

  Future<void> _clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => FolderViewModel()),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => FilesViewModel()),
        ChangeNotifierProvider(create: (_) => QuizSetsViewModel()),

        ChangeNotifierProvider(create: (_) => UserViewModel()),
        
        
        // Add more providers here
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EMA APP',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: false,
        ),
        home: const HomePage(
          userIdentifier: '',
          isAdmin: false,
          fullName: '',
        ),
        routes: {
          '/quizSetDetail': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
            if (args == null) return const SizedBox.shrink();
            return QuizSetDetailPage(
              quizSetId: args['quizSetId'] ?? '',
              quizSetName: args['quizSetName'] ?? '',
            );
          },
        },
      ),
    );
  }
}
