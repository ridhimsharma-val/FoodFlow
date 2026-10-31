import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'pages/dashboard.dart';
import 'pages/provider/provider_dashboard.dart';
import 'pages/support_page.dart';
import 'services/auth_service.dart';
import 'services/consent_service.dart';
import 'services/supabase_service.dart';
import 'widgets/app_drawer.dart';
import 'widgets/brand_logo.dart';
import 'widgets/terms_and_conditions_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase init warning: $e');
  }
  try {
    await FoodFlowConsentService.instance.initialize();
  } catch (e) {
    debugPrint('Consent service init warning: $e');
  }
  runApp(const FoodFlowApp());
}

class FoodFlowApp extends StatelessWidget {
  const FoodFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.pageBackground,
        primaryColor: AppColors.primaryGold,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGold,
          primary: AppColors.primaryGold,
          surface: AppColors.pageBackground,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/provider': (context) => const ProviderDashboard(),
        '/support': (context) => const SupportPage(),
      },
    );
  }
}

/// Reactive gate that automatically switches between Welcome/Login and Dashboard
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserProfile? _cachedProfile;
  bool _isLoadingProfile = false;
  String? _loadedUserId;

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isInitialized) {
      return const WelcomeScreen();
    }

    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? SupabaseService.client.auth.currentSession;
        final user = session?.user ?? SupabaseService.currentUser;

        if (session != null || (user != null && SupabaseService.isAuthenticated)) {
          if (user == null) {
            return const DashboardPage();
          }

          if (_loadedUserId != user.id) {
            _loadedUserId = user.id;
            _isLoadingProfile = true;
            final intendedRole = kIsWeb ? Uri.base.queryParameters['role'] : null;

            () async {
              try {
                if (intendedRole != null && intendedRole.isNotEmpty) {
                  await SupabaseService.syncUserProfile(user, intendedRole);
                }
              } catch (_) {}
              final p = await AuthService.instance.fetchProfile(forceRefresh: true);
              if (mounted) {
                setState(() {
                  _cachedProfile = p;
                  _isLoadingProfile = false;
                });
              }
            }();
          }

          if (_isLoadingProfile && _cachedProfile == null) {
            return const Scaffold(
              backgroundColor: AppColors.pageBackground,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryGold),
                    SizedBox(height: 16),
                    Text(
                      'Verifying Food Flow session...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final hasConsent = FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync() ||
              _cachedProfile?.termsAcceptedVersion == FoodFlowConsentService.currentTermsVersion;

          if (!hasConsent) {
            return Scaffold(
              backgroundColor: AppColors.pageBackground,
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FoodFlowLogoBox(),
                          const SizedBox(height: 20),
                          const Text(
                            'Updated Platform Agreement',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Food Flow has updated its Terms & Conditions and Privacy Notice. '
                            'Please review and acknowledge the updated agreement to access your dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                final accepted = await TermsAndConditionsDialog.show(context);
                                if (accepted == true && mounted) {
                                  setState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGold,
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Review & Accept Agreement',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Ensure profile and local consent records are kept in sync
          FoodFlowConsentService.instance.checkAndSyncWithProfile(_cachedProfile);

          final role = _cachedProfile?.role ?? 'provider';
          return DashboardPage(initialRole: role);
        }

        _loadedUserId = null;
        _cachedProfile = null;
        _isLoadingProfile = false;
        return const WelcomeScreen();
      },
    );
  }
}

/// The initial landing screen in main.dart that navigates to login.dart
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _hasAcceptedTerms = false;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _hasAcceptedTerms = FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync();
    FoodFlowConsentService.instance.addListener(_onConsentChanged);

    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegalModal(LegalDocumentType.termsAndConditions);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegalModal(LegalDocumentType.privacyPolicy);
  }

  @override
  void dispose() {
    FoodFlowConsentService.instance.removeListener(_onConsentChanged);
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _onConsentChanged() {
    if (mounted) {
      setState(() {
        _hasAcceptedTerms = FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync();
      });
    }
  }

  Future<void> _openLegalModal(LegalDocumentType documentType) async {
    final accepted = await TermsAndConditionsDialog.show(
      context,
      documentType: documentType,
    );
    if (accepted == true && mounted) {
      setState(() {
        _hasAcceptedTerms = true;
      });
    }
  }

  void _handleLoginButtonPressed() {
    if (!_hasAcceptedTerms) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF18181B),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primaryGold, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please read the Terms & Conditions and accept them before continuing.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    UserRole? role;
    if (kIsWeb && Uri.base.queryParameters.containsKey('role')) {
      role = UserRole.values.asNameMap()[Uri.base.queryParameters['role']?.toLowerCase()];
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(initialRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: SupabaseService.isAuthenticated
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                AppDrawer.buildSignOutButton(context),
                const SizedBox(width: 16),
              ],
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Food Flow Word Mark Logo
                    const FoodFlowWordmark(
                      width: 150,
                      height: 120,
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Food Flow',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      'Surplus Food Rescue & Logistics Redistribution Platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Feature highlights pill chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildChip(
                          icon: Icons.flash_on_rounded,
                          label: 'Real-Time Dispatch',
                        ),
                        _buildChip(
                          icon: Icons.verified_rounded,
                          label: 'Verified Compliance',
                        ),
                        _buildChip(
                          icon: Icons.sync_rounded,
                          label: 'Live Redistribution',
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Navigation Button to login.dart (Always Golden Yellow)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handleLoginButtonPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Go to Login & Setup',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Legal Consent & Terms / Privacy Notice clickable link text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to our ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: AppColors.textGoldKicker,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textGoldKicker,
                              ),
                              recognizer: _termsRecognizer,
                            ),
                            const TextSpan(text: ' and acknowledge our '),
                            TextSpan(
                              text: 'Privacy Notice',
                              style: const TextStyle(
                                color: AppColors.textGoldKicker,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textGoldKicker,
                              ),
                              recognizer: _privacyRecognizer,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ruleBannerBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderRuleBanner,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textRule),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textRule,
            ),
          ),
        ],
      ),
    );
  }
}
