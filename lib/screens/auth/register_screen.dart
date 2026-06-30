import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/constants/app_strings.dart';
import '../../core/utils/validators/email_validator.dart';
import '../../core/utils/validators/password_validator.dart';
import '../../core/utils/validators/phone_validator.dart';
import '../../core/widgets/buttons/wb_button.dart';
import '../../core/widgets/inputs/wb_text_field.dart';
import '../../providers/auth/auth_provider.dart';

/// 📝 REGISTER SCREEN
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      businessName: _businessNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimens.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.xxl),

                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(height: AppDimens.md),

                // Title
                Text(
                  'Create Account',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.xs),
                Text(
                  'Start managing your WhatsApp Business',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.xl),

                // ============ ERROR BANNER ============
                if (authState.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppDimens.md),
                    padding: const EdgeInsets.all(AppDimens.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(color: AppColors.error.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ============ GOOGLE SIGN-UP ============
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: authState.isLoading ? null : _handleGoogleSignIn,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4285F4),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Sign up with Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3C4043),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),

                // ============ DIVIDER ============
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outline.withAlpha(40))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                      child: Text(
                        'OR',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outline.withAlpha(40))),
                  ],
                ),
                const SizedBox(height: AppDimens.md),

                // Business Name
                WbTextField(
                  label: AppStrings.businessName,
                  hint: 'Your business name',
                  controller: _businessNameController,
                  prefixIcon: const Icon(Icons.business_outlined),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.md),

                // Email
                WbTextField(
                  label: AppStrings.email,
                  hint: 'Enter your email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: EmailValidator.validate,
                  prefixIcon: const Icon(Icons.email_outlined),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.md),

                // Phone
                WbTextField(
                  label: AppStrings.phoneNumber,
                  hint: '+92 300 1234567',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: PhoneValidator.validate,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.md),

                // Password
                WbTextField(
                  label: AppStrings.password,
                  hint: 'Create a strong password',
                  controller: _passwordController,
                  isPassword: true,
                  validator: PasswordValidator.validate,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.md),

                // Confirm Password
                WbTextField(
                  label: AppStrings.confirmPassword,
                  hint: 'Confirm your password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  validator: (value) => PasswordValidator.validateConfirm(
                    value,
                    _passwordController.text,
                  ),
                  prefixIcon: const Icon(Icons.lock_outlined),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppDimens.xl),

                // Register Button
                WbButton(
                  text: AppStrings.signUp,
                  onPressed: _handleRegister,
                  isLoading: authState.isLoading,
                  icon: Icons.person_add,
                ),
                const SizedBox(height: AppDimens.xl),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.alreadyHaveAccount,
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text(AppStrings.signIn),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
