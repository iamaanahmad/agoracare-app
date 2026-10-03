import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/routes.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: cardShadow,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 14),
                Text(user?.displayName ?? 'Guest Patient',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Anonymous · Secure',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Language
          _SectionCard(
            title: 'Language Preference',
            child: Row(
              children: [
                Expanded(
                  child: _LangOption(
                    label: 'English',
                    sublabel: 'en-IN',
                    selected: lang == 'en-IN',
                    onTap: () => ref
                        .read(languageProvider.notifier)
                        .setLanguage('en-IN'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LangOption(
                    label: 'हिंदी',
                    sublabel: 'hi-IN',
                    selected: lang == 'hi-IN',
                    onTap: () => ref
                        .read(languageProvider.notifier)
                        .setLanguage('hi-IN'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nurse mode
          _SectionCard(
            title: 'Healthcare Provider',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medical_services_rounded,
                    color: AppColors.danger, size: 22),
              ),
              title: const Text('Live Nurse Dashboard',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              subtitle: const Text('View & respond to emergency escalations',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textHint, size: 14),
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.nurseDashboard),
            ),
          ),
          const SizedBox(height: 24),

          // Sign out
          OutlinedButton.icon(
            onPressed: () async {
              await signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.auth);
              }
            },
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.textMuted, size: 18),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.textMuted)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption(
      {required this.label,
      required this.sublabel,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecond,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(sublabel,
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
