import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  // General URL launcher with error handling
  Future<void> _launchUrl(String url, BuildContext context, {String? errorMessage}) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('Launched URL: $url');
      } else {
        debugPrint('Cannot launch URL: $url');
        _showSnackBar(context, errorMessage ?? 'No browser available to open $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $url, Error: $e');
      _showSnackBar(context, errorMessage ?? 'Failed to open $url');
    }
  }

  // Facebook-specific launcher with deep linking
  Future<void> _openFacebook(BuildContext context) async {
    const String pageId = 'yogendra.wagle.12';
    const String fallbackUrl = 'https://www.facebook.com/yogendra.wagle.12';
    String fbProtocolUrl;

    try {
      if (Platform.isIOS) {
        fbProtocolUrl = 'fb://profile/$pageId';
      } else if (Platform.isAndroid) {
        fbProtocolUrl = 'fb://page/$pageId';
      } else {
        fbProtocolUrl = fallbackUrl;
      }

      final Uri fbUri = Uri.parse(fbProtocolUrl);
      final Uri webUri = Uri.parse(fallbackUrl);

      if (await canLaunchUrl(fbUri)) {
        await launchUrl(fbUri, mode: LaunchMode.externalApplication);
        debugPrint('Launched Facebook app: $fbProtocolUrl');
      } else {
        debugPrint('Falling back to browser for Facebook: $fallbackUrl');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening Facebook: $e');
      _showSnackBar(context, 'Failed to open Facebook');
    }
  }

  // Email launcher with Gmail app and browser fallback
 Future<void> _launchGmail(String email, BuildContext context) async {
  final String fallbackUrl = 'https://mail.google.com/mail/?view=cm&fs=1&to=$email';
  String gmailProtocolUrl;

  try {
    if (Platform.isIOS) {
      gmailProtocolUrl = 'googlegmail:///co?to=$email';
    } else if (Platform.isAndroid) {
      // Explicitly target Gmail app with intent
gmailProtocolUrl = 'intent://sendto/mailto:$email#Intent;package=com.google.android.gm;action=android.intent.action.SENDTO;scheme=mailto;end';    } else {
      gmailProtocolUrl = fallbackUrl;
    }

    final Uri gmailUri = Uri.parse(gmailProtocolUrl);
    final Uri webUri = Uri.parse(fallbackUrl);

    if (await canLaunchUrl(gmailUri)) {
      await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
      debugPrint('Launched Gmail app: $gmailProtocolUrl');
    } else {
      debugPrint('Falling back to browser for Gmail: $fallbackUrl');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Error opening Gmail: $e');
    _showSnackBar(context, 'Failed to open Gmail');
  }
}


  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    await _launchUrl(phoneUri.toString(), context, errorMessage: 'No phone app available');
  }

  void _copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      _showSnackBar(context, 'Copied to clipboard', isSuccess: true);
    }).catchError((error) {
      _showSnackBar(context, 'Failed to copy to clipboard');
    });
  }

  // Custom SnackBar with styling
  void _showSnackBar(BuildContext context, String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact Us',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 4,
        shadowColor: Colors.black54,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Get in Touch',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reach out to us through any of the following methods:',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _buildContactCard(
                context,
                icon: Icons.email,
                title: 'Email',
                value: 'info@emaeducation.com.np',
                onTap: () => _launchGmail('info@emaeducation.com.np', context),
                onCopy: () => _copyToClipboard('info@emaeducation.com.np', context),
              ),
              _buildContactCard(
                context,
                icon: Icons.phone,
                title: 'Phone',
                value: '+9779851213520',
                onTap: () => _makePhoneCall('+9779851213520', context),
                onCopy: () => _copyToClipboard('+9779851213520', context),
              ),
              
              _buildContactCard(
                context,
                icon: Icons.location_on,
                title: 'Location',
                value: 'Google Maps',
                onTap: () => _launchUrl('https://maps.app.goo.gl/Gi5NHBVwapFgKASf9', context, errorMessage: 'No maps app available'),
                onCopy: () => _copyToClipboard('https://maps.app.goo.gl/Gi5NHBVwapFgKASf9', context),
              ),
              _buildContactCard(
                context,
                icon: Icons.facebook,
                title: 'Facebook',
                value: 'yogendra.wagle.12',
                onTap: () => _openFacebook(context),
                onCopy: () => _copyToClipboard('https://www.facebook.com/yogendra.wagle.12', context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable contact card widget
  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.teal, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onCopy,
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: const Icon(Icons.copy, color: Colors.grey, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}