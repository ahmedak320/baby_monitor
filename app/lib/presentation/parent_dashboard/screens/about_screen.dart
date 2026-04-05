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
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DevSettingsScreen()));
    } else if (_versionTapCount >= 4 && _versionTapCount < 7 && kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - _versionTapCount} taps to developer settings'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _openLegal(String title, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalTextScreen(title: title, content: content),
      ),
    );
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

          // Legal section header
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'LEGAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.0,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _openLegal('Privacy Policy', LegalContent.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _openLegal('Terms of Service', LegalContent.termsOfService),
          ),
          ListTile(
            leading: const Icon(Icons.child_care_outlined),
            title: const Text("Children's Privacy Notice"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              "Children's Privacy Notice",
              LegalContent.childrensPrivacyNotice,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI Filtering Disclaimer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'AI Content Filtering Disclaimer',
              LegalContent.aiFilteringDisclaimer,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('California Privacy Notice'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'California Privacy Notice',
              LegalContent.ccpaNotice,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payment_outlined),
            title: const Text('Subscription Terms'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'Subscription Terms',
              LegalContent.subscriptionTerms,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Third-Party Services'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'Third-Party Service Disclosure',
              LegalContent.thirdPartyDisclosure,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Acceptable Use Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'Acceptable Use Policy',
              LegalContent.acceptableUsePolicy,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copyright_outlined),
            title: const Text('Copyright / DMCA Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _openLegal('Copyright / DMCA Policy', LegalContent.dmcaPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Data Breach Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'Data Breach Notification Policy',
              LegalContent.dataBreachPolicy,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.accessibility_new_outlined),
            title: const Text('Accessibility Statement'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLegal(
              'Accessibility Statement',
              LegalContent.accessibilityStatement,
            ),
          ),

          const Divider(),

          // Support & account
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Support'),
            subtitle: const Text(AppMetadata.supportEmail),
            onTap: () {
              // Could launch mailto: link
            },
          ),
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
