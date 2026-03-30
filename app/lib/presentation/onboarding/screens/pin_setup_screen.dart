import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/route_names.dart';
import '../providers/onboarding_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onNext() {
    final pin = _pinController.text;
    final confirm = _confirmController.text;

    if (pin.length != 4) {
      setState(() => _errorText = 'PIN must be 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorText = 'PINs do not match');
      return;
    }

    setState(() => _errorText = null);
    ref.read(onboardingProvider.notifier).setPin(pin);
    context.pushNamed(RouteNames.setupComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Set a Parent PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This 4-digit PIN protects kid mode so only you can '
                'switch profiles or exit. You can change it later in settings.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Enter PIN',
                  hintText: '4-digit PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  hintText: 'Re-enter PIN',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _onNext(),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onNext,
                  child: const Text('Next'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
