import 'dart:async';
import 'package:ema_app/screens/admin/admin_dashboard_page.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/screens/users/user_home_page.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../model/user_model.dart';

class FlashScreen extends StatefulWidget {
  const FlashScreen({super.key});

  @override
  State<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends State<FlashScreen> {
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _startSplashScreen();
  }

  Future<void> _startSplashScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    await _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final userViewModel = UserViewModel();
    final UserModel? user = await userViewModel.getUser();

    if (user != null && user.success == true) {
      logger.i("User found: ${user.email}, ${user.fullName} ${user.fullName}role: ${user.role}");

      if (user.role == "admin") {
        _navigateTo(AdminDashboardPage(
          fullName: user.fullName ?? user.fullName ?? '',
          profileImage: user.image ?? '',
          isAdmin: true,
          userEmail: user.email ?? '',
        ));
      } else {
        _navigateTo(UserHomePage(
          fullName: user.fullName ?? user.fullName ?? '',
          profileImage: user.image ?? '',
          isAdmin: false,
          userEmail: user.email ?? '',
          userIdentifier:  user.email ?? '',   // example: using phone as identifier
          folderId: '',                       // you can adjust this based on your logic
          folderName: '',
        ));
      }
    } else {
      logger.i("No user found, going to HomePage");
      _navigateTo(const HomePage(
        userIdentifier: '',
        isAdmin: false,
        fullName: '',
      ));
    }
  }

  void _navigateTo(Widget route) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => route),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Image(
          image: AssetImage('assets/ema.jpg'),
          height: 300,
        ),
      ),
    );
  }
}
