import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/legal_content.dart';
import '../../../routing/route_names.dart';
import '../../../utils/validators.dart';
import '../../common/widgets/legal_text_screen.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _agreedToTerms = false;
  bool _confirmedAge = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSignup => _agreedToTerms && _confirmedAge;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSignup(),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Terms & Privacy consent checkbox
                _ConsentCheckbox(
                  value: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  child: Text.rich(
                    TextSpan(
                      text: 'I have read and agree to the ',
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        _linkSpan(context, 'Terms of Service', () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LegalTextScreen(
                                title: 'Terms of Service',
                                content: LegalContent.termsOfService,
                              ),
                            ),
                          );
                        }),
                        const TextSpan(text: ' and '),
                        _linkSpan(context, 'Privacy Policy', () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LegalTextScreen(
                                title: 'Privacy Policy',
                                content: LegalContent.privacyPolicy,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Age & guardian confirmation checkbox
                _ConsentCheckbox(
                  value: _confirmedAge,
                  onChanged: (v) => setState(() => _confirmedAge = v ?? false),
                  child: Text(
                    'I confirm I am 18 years of age or older and am the '
                    'parent or legal guardian of any child whose profile I '
                    'create',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading || !_canSignup
                      ? null
                      : _handleSignup,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _linkSpan(BuildContext context, String text, VoidCallback onTap) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
        fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
      ),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSignup) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Check your email to verify.'),
        ),
      );
      context.goNamed(RouteNames.dashboard);
    }
  }
}

class _ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget child;

  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
