import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_metadata.dart';
import '../../../config/legal_content.dart';
import '../../../routing/route_names.dart';
import '../../common/widgets/legal_text_screen.dart';
import 'dev_settings_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _versionTapCount = 0;

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 7 && kDebugMode) {
      _versionTapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DevSettingsScreen()),
      );
    } else if (_versionTapCount >= 4 && _versionTapCount < 7 && kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - _versionTapCount} taps to developer settings'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App info
          Center(
            child: Column(
              children: [
                const Icon(Icons.shield, size: 64, color: Color(0xFF6C63FF)),
                const SizedBox(height: 12),
                const Text(
                  AppMetadata.appName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _onVersionTap,
                  child: Text(
                    'Version ${AppMetadata.appVersion}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  AppMetadata.shortDescription,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Legal
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LegalTextScreen(
                  title: 'Privacy Policy',
                  content: LegalContent.privacyPolicy,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LegalTextScreen(
                  title: 'Terms of Service',
                  content: LegalContent.termsOfService,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Support'),
            subtitle: const Text(AppMetadata.supportEmail),
            onTap: () {
              // Could launch mailto: link
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Account Settings'),
            subtitle: const Text('Manage profiles & delete account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.goNamed(RouteNames.accountSettings),
          ),
        ],
      ),
    );
  }
}
