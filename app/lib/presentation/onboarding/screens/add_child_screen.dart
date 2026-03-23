import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../providers/onboarding_provider.dart';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  int _selectedAvatarIndex = 0;

  static const _avatarIcons = [
    Icons.child_care,
    Icons.face,
    Icons.pets,
    Icons.star,
    Icons.favorite,
    Icons.emoji_nature,
  ];

  static const _avatarColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFF6C63FF),
    Color(0xFFFF9FF3),
    Color(0xFF54A0FF),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Your Child'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell us about your child',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll personalize content based on their age.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),

              // Avatar picker
              Text(
                'Choose an avatar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatarIcons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedAvatarIndex;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedAvatarIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: _avatarColors[index]
                              .withValues(alpha: isSelected ? 1.0 : 0.3),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _avatarColors[index]
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          _avatarIcons[index],
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Child\'s name',
                  prefixIcon: Icon(Icons.person_outlined),
                  hintText: 'e.g., Emma',
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              // Date of birth picker
              Text(
                'Date of Birth',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate != null
                            ? DateFormat('MMMM d, yyyy')
                                .format(_selectedDate!)
                            : 'Tap to select date of birth',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedDate != null
                              ? null
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Age: ${AgeCalculator.yearsFromDob(_selectedDate!)} years old '
                  '(${AgeCalculator.ageBracket(_selectedDate!)})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6C63FF),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
              const SizedBox(height: 40),

              // Next button
              ElevatedButton(
                onPressed: _canProceed ? _handleNext : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canProceed =>
      _nameController.text.trim().isNotEmpty && _selectedDate != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(now.year - 12),
      lastDate: now,
      helpText: 'Select child\'s date of birth',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleNext() {
    final notifier = ref.read(onboardingProvider.notifier);
    notifier.setChildName(_nameController.text.trim());
    notifier.setChildDob(_selectedDate!);
    context.pushNamed(RouteNames.filterSetup);
  }
}
