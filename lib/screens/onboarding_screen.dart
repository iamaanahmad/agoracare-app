import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/routes.dart';
import '../providers/auth_provider.dart';

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bgColor;
  const _OnboardPage(this.icon, this.title, this.subtitle, this.color, this.bgColor);
}

const _pages = [
  _OnboardPage(Icons.mic_rounded, 'Talk to Your AI Doctor',
      'Speak in Hindi or English. Aria understands you naturally and responds instantly.',
      AppColors.primary, AppColors.primaryLight),
  _OnboardPage(Icons.medication_rounded, 'Never Miss a Medication',
      'Aria reminds you of every dose and tracks your daily adherence automatically.',
      AppColors.success, AppColors.successLight),
  _OnboardPage(Icons.emergency_rounded, 'Emergency? We\'ve Got You',
      'One tap connects you to a live nurse instantly over crystal-clear voice.',
      AppColors.danger, AppColors.dangerLight),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14)),
                  ),
                  // Lang toggle
                  Row(
                    children: [
                      _LangChip(
                        label: 'EN',
                        selected: lang == 'en-IN',
                        onTap: () => ref
                            .read(languageProvider.notifier)
                            .setLanguage('en-IN'),
                      ),
                      const SizedBox(width: 6),
                      _LangChip(
                        label: 'हि',
                        selected: lang == 'hi-IN',
                        onTap: () => ref
                            .read(languageProvider.notifier)
                            .setLanguage('hi-IN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageView(page: _pages[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: isLast
                    ? _finish
                    : () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        ),
                child: Text(isLast ? 'Get Started' : 'Next'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.auth);
  }
}

class _PageView extends StatelessWidget {
  final _OnboardPage page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.bgColor,
              border: Border.all(
                  color: page.color.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(page.icon, color: page.color, size: 58),
          ),
          const SizedBox(height: 40),
          Text(page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
          const SizedBox(height: 16),
          Text(page.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 15, height: 1.65)),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}
