import 'package:ema_app/eps_section_page.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/screens/users/user_notices_page.dart';
import 'package:ema_app/screens/users/contactuspage.dart';
import 'package:ema_app/screens/auth/login_user_free_files_quiz_sets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/admin_dashboard_page.dart';
import 'dart:io' show Platform;

class UserHomePage extends StatefulWidget {
  final String fullName;
  final String profileImage;
  final bool isAdmin;
  final bool accessedFromAdminDashboard;
  final String userEmail;
  final String userIdentifier;
  final int? folderId;
  final String folderName;

  const UserHomePage({
    super.key,
    required this.fullName,
    required this.profileImage,
    required this.isAdmin,
    required this.userEmail,
    this.accessedFromAdminDashboard = false,
    required this.userIdentifier,
    required this.folderId,
    required this.folderName,
  });

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  late SharedPreferences _prefs;
  String? _cachedFullName;
  String? _cachedProfileImage;
  String? _cachedUserEmail;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _initSharedPreferences();
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.setString('fullName', widget.fullName);
    await _prefs.setString('profileImage', widget.profileImage);
    await _prefs.setString('userEmail', widget.userEmail);
    await _prefs.setString('userIdentifier', widget.userIdentifier);
    await _prefs.setBool('isAdmin', widget.isAdmin);

    setState(() {
      _cachedFullName = _prefs.getString('fullName') ?? widget.fullName;
      _cachedProfileImage = _prefs.getString('profileImage') ?? widget.profileImage;
      _cachedUserEmail = _prefs.getString('userEmail') ?? widget.userEmail;
    });
  }

  ScreenSize _getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenSize.small;
    if (width < 1024) return ScreenSize.medium;
    return ScreenSize.large;
  }

  ResponsiveDimensions _getResponsiveDimensions(BuildContext context) {
    final screenSize = _getScreenSize(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    switch (screenSize) {
      case ScreenSize.small:
        return ResponsiveDimensions(
          padding: screenWidth * 0.04,
          logoHeight: screenHeight * 0.15,
          logoWidth: screenWidth * 0.6,
          titleFontSize: screenWidth * 0.045,
          buttonWidth: screenWidth * 0.42,
          buttonHeight: screenHeight * 0.12,
          buttonFontSize: screenWidth * 0.028,
          iconSize: screenWidth * 0.08,
          crossAxisCount: 2,
          childAspectRatio: 0.9,
        );
      case ScreenSize.medium:
        return ResponsiveDimensions(
          padding: screenWidth * 0.03,
          logoHeight: screenHeight * 0.18,
          logoWidth: screenWidth * 0.4,
          titleFontSize: screenWidth * 0.035,
          buttonWidth: screenWidth * 0.28,
          buttonHeight: screenHeight * 0.14,
          buttonFontSize: screenWidth * 0.022,
          iconSize: screenWidth * 0.06,
          crossAxisCount: 3,
          childAspectRatio: 0.8,
        );
      case ScreenSize.large:
        return ResponsiveDimensions(
          padding: 24.0,
          logoHeight: 200.0,
          logoWidth: 300.0,
          titleFontSize: 24.0,
          buttonWidth: 180.0,
          buttonHeight: 140.0,
          buttonFontSize: 13.0,
          iconSize: 32.0,
          crossAxisCount: 4,
          childAspectRatio: 1.0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _getResponsiveDimensions(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Empower Your Future",
          style: TextStyle(
            fontSize: _getScreenSize(context) == ScreenSize.small 
                ? screenWidth * 0.045 
                : _getScreenSize(context) == ScreenSize.medium 
                    ? screenWidth * 0.03 
                    : 20.0,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 6,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.cyanAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: _buildDrawer(context, dimensions),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.teal[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(dimensions.padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    alignment: Alignment.center,
                    height: dimensions.logoHeight,
                    child: Image.asset(
                      "assets/ema.jpeg",
                      width: dimensions.logoWidth,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported, 
                        size: dimensions.logoWidth * 0.3, 
                        color: Colors.grey
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    "Welcome to EMA UBT, ${_cachedFullName ?? widget.fullName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                      fontSize: dimensions.titleFontSize,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  _buildResponsiveButtonGrid(context, dimensions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveButtonGrid(BuildContext context, ResponsiveDimensions dimensions) {
    final screenSize = _getScreenSize(context);
    
    if (screenSize == ScreenSize.large) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: dimensions.crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: dimensions.childAspectRatio,
          children: _buildButtonList(dimensions),
        ),
      );
    } else {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 16,
        children: _buildButtonList(dimensions),
      );
    }
  }

  List<Widget> _buildButtonList(ResponsiveDimensions dimensions) {
    return [
      _buildLargeButton(
        dimensions,
        const Icon(Icons.notifications, color: Colors.white),
        'Important Information',
        Colors.deepPurple[600]!,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserNoticesPage())),
      ),
      _buildLargeButton(
        dimensions,
        const Icon(Icons.file_copy, color: Colors.white),
        'Free Files & Quiz Sets',
        Colors.blue[600]!,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginUserFreeFilesQuizSets(
              userIdentifier: _cachedUserEmail ?? widget.userEmail,
              isAdmin: widget.isAdmin,
            ),
          ),
        ),
      ),
      if (widget.isAdmin || widget.accessedFromAdminDashboard)
        _buildLargeButton(
          dimensions,
          const Icon(Icons.admin_panel_settings, color: Colors.white),
          'Admin Dashboard',
          Colors.teal[600]!,
          () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardPage(
                fullName: _cachedFullName ?? widget.fullName,
                profileImage: _cachedProfileImage ?? widget.profileImage,
                isAdmin: widget.isAdmin,
                userEmail: _cachedUserEmail ?? widget.userEmail,
              ),
            ),
          ),
        ),
      _buildLargeButton(
        dimensions,
        Image.asset(
          "assets/ema.jpg",
          width: dimensions.iconSize,
          height: dimensions.iconSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_not_supported, 
            size: dimensions.iconSize, 
            color: Colors.white
          ),
        ),
        'EPS TOPIK NEW UBT SESSION',
        Colors.green[600]!,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EPSSectionPage(
              userIdentifier: _cachedUserEmail ?? widget.userEmail,
              isAdmin: widget.isAdmin, fullName: '', profileImage: '', userEmail: '', folderId: null, folderName: '',
            ),
          ),
        ),
      ),
      _buildLargeButton(
        dimensions,
        const Icon(Icons.contact_mail, color: Colors.white),
        'Contact Us',
        Colors.red[600]!,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsPage())),
      ),
      _buildLargeButton(
        dimensions,
        const Icon(Icons.logout, color: Colors.white),
        'Logout',
        Colors.grey[600]!,
        () => _handleLogout(context),
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context, ResponsiveDimensions dimensions) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenSize = _getScreenSize(context);

    return Drawer(
      width: screenSize == ScreenSize.small 
          ? screenWidth * 0.8 
          : screenSize == ScreenSize.medium 
              ? screenWidth * 0.6 
              : 300,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal[700]!, Colors.cyanAccent]),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: screenSize == ScreenSize.small 
                        ? 28 
                        : screenSize == ScreenSize.medium 
                            ? 32 
                            : 35,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.account_circle,
                      size: screenSize == ScreenSize.small 
                          ? 35 
                          : screenSize == ScreenSize.medium 
                              ? 40 
                              : 45,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      "Hello, ${widget.isAdmin ? 'Admin' : 'User'}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenSize == ScreenSize.small 
                            ? 16 
                            : screenSize == ScreenSize.medium 
                                ? 18 
                                : 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      _cachedUserEmail ?? widget.userEmail,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: screenSize == ScreenSize.small 
                            ? 12 
                            : screenSize == ScreenSize.medium 
                                ? 14 
                                : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  dimensions,
                  const Icon(Icons.notifications, color: Colors.teal),
                  "Important Information",
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserNoticesPage())),
                ),
                _buildDrawerItem(
                  context,
                  dimensions,
                  Image.asset(
                    "assets/ema.jpg",
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported,
                      size: 20,
                      color: Colors.teal,
                    ),
                  ),
                  "EPS TOPIK NEW UBT SESSION",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EPSSectionPage(
                        userIdentifier: _cachedUserEmail ?? widget.userEmail,
                        isAdmin: widget.isAdmin, fullName: '', profileImage: '', userEmail: '', folderId: null, folderName: '',
                      ),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  dimensions,
                  const Icon(Icons.file_copy, color: Colors.teal),
                  "Free Files & Quiz Sets",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginUserFreeFilesQuizSets(
                        userIdentifier: _cachedUserEmail ?? widget.userEmail,
                        isAdmin: widget.isAdmin,
                      ),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  dimensions,
                  const Icon(Icons.contact_mail, color: Colors.teal),
                  "Contact Us",
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsPage())),
                ),
                if (widget.isAdmin || widget.accessedFromAdminDashboard)
                  _buildDrawerItem(
                    context,
                    dimensions,
                    const Icon(Icons.admin_panel_settings, color: Colors.teal),
                    "Admin Dashboard",
                    () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminDashboardPage(
                          fullName: _cachedFullName ?? widget.fullName,
                          profileImage: _cachedProfileImage ?? widget.profileImage,
                          isAdmin: widget.isAdmin,
                          userEmail: _cachedUserEmail ?? widget.userEmail,
                        ),
                      ),
                    ),
                  ),
                _buildDrawerItem(
                  context,
                  dimensions,
                  const Icon(Icons.logout, color: Colors.teal),
                  "Logout",
                  () => _handleLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _prefs.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(
            userIdentifier: '',
            isAdmin: false,
            fullName: '',
          ),
        ),
        (route) => false,
      );
    }
  }

  Widget _buildLargeButton(
    ResponsiveDimensions dimensions,
    Widget icon,
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: dimensions.buttonWidth,
      height: dimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: dimensions.buttonHeight * 0.4,
              child: icon is Icon
                  ? Icon(
                      (icon).icon,
                      size: dimensions.iconSize,
                      color: Colors.white,
                    )
                  : SizedBox(
                      width: dimensions.iconSize,
                      height: dimensions.iconSize,
                      child: icon,
                    ),
            ),
            SizedBox(height: 4),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: dimensions.buttonFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, 
    ResponsiveDimensions dimensions,
    Widget leading, 
    String title, 
    VoidCallback onTap
  ) {
    final screenSize = _getScreenSize(context);
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: leading,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: screenSize == ScreenSize.small 
                ? 14 
                : screenSize == ScreenSize.medium 
                    ? 16 
                    : 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        tileColor: Colors.white,
        selectedTileColor: Colors.teal[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        minLeadingWidth: 36,
      ),
    );
  }
}

enum ScreenSize { small, medium, large }

class ResponsiveDimensions {
  final double padding;
  final double logoHeight;
  final double logoWidth;
  final double titleFontSize;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonFontSize;
  final double iconSize;
  final int crossAxisCount;
  final double childAspectRatio;

  ResponsiveDimensions({
    required this.padding,
    required this.logoHeight,
    required this.logoWidth,
    required this.titleFontSize,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.buttonFontSize,
    required this.iconSize,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });
}