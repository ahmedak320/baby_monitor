import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/route_names.dart';
import '../providers/onboarding_provider.dart';

/// Onboarding screen where the parent creates a 4-digit PIN.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _controller = TextEditingController();
  bool _isConfirming = false;
  String _firstPin = '';
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNext() {
    final pin = _controller.text;
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }

    if (!_isConfirming) {
      // Move to confirm phase
      _firstPin = pin;
      _controller.clear();
      setState(() {
        _isConfirming = true;
        _error = null;
      });
    } else {
      // Confirm phase — check match
      if (pin == _firstPin) {
        ref.read(onboardingProvider.notifier).setParentPin(pin);
        context.pushNamed(RouteNames.setupComplete);
      } else {
        // Mismatch — reset to create phase
        _controller.clear();
        setState(() {
          _isConfirming = false;
          _firstPin = '';
          _error = 'PINs did not match. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isConfirming) {
              // Go back to create phase
              _controller.clear();
              setState(() {
                _isConfirming = false;
                _firstPin = '';
                _error = null;
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                _isConfirming ? Icons.check_circle_outline : Icons.lock_outline,
                size: 64,
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Create a Parent PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter the same PIN again to confirm.'
                    : 'This PIN protects kid mode. You\'ll need it to\nstart or exit kid mode when biometrics aren\'t available.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, letterSpacing: 12),
                  decoration: InputDecoration(
                    hintText: '····',
                    counterText: '',
                    errorText: _error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _handleNext(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleNext,
                child: Text(_isConfirming ? 'Confirm' : 'Next'),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
