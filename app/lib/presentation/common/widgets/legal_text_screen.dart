import 'package:flutter/material.dart';

/// Reusable screen for displaying legal text (privacy policy, terms of service).
class LegalTextScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalTextScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          content,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}
