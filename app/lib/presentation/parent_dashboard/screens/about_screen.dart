import 'package:flutter/material.dart';

import '../../../config/app_metadata.dart';
import '../../../config/legal_content.dart';
import '../../common/widgets/legal_text_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App info
          const Center(
            child: Column(
              children: [
                Icon(Icons.shield, size: 64, color: Color(0xFF6C63FF)),
                SizedBox(height: 12),
                Text(
                  AppMetadata.appName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Version ${AppMetadata.appVersion}',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
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
        ],
      ),
    );
  }
}
