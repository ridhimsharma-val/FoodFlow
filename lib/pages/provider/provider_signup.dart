import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/six_digit_otp_input.dart';
import '../dashboard.dart';

class ProviderSignUpPage extends StatefulWidget {
  const ProviderSignUpPage({super.key});

  @override
  State<ProviderSignUpPage> createState() => _ProviderSignUpPageState();
}

class _ProviderSignUpPageState extends State<ProviderSignUpPage> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  late final TextEditingController _orgNameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  // OTP Controllers
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  String _selectedCategory = 'Hostel / University Mess';
  int _currentStep = 0;
  bool _otpSent = false;
  int _resendCountdown = 60;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _isDetectingLocation = false;
  bool _locationDetected = false;

  final List<String> _categories = [
    'Restaurant / Hotel',
    'Hostel / University Mess',
    'Catering Service',
    'Bakery & Confectionery',
    'Event Banquet Hall',
  ];


  @override
  void initState() {
    super.initState();
    _orgNameController = TextEditingController();
    _contactPersonController = TextEditingController();
    final initialLoc = LocationService.currentProviderLocation;
    _addressController = TextEditingController(
      text: initialLoc?.displayAddress ?? '',
    );
    if (initialLoc != null) {
      _locationDetected = true;
    }
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _otpControllers = List.generate(8, (_) => TextEditingController());
    _otpFocusNodes = List.generate(8, (_) => FocusNode());

    if (initialLoc == null || !LocationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _addressController.text.trim().isEmpty) {
          _detectLocation();
        }
      });
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final result = await LocationService.detectCurrentLocation();
      if (result != null && mounted) {
        setState(() {
          _locationDetected = true;
          _addressController.text = result.displayAddress;
        });
        LocationService.setProviderLocation(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            content: Text(
              '📍 Location detected: ${_addressController.text}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orangeAccent,
            content: Text(
              'Could not auto-detect location. Please check browser GPS permission or enter location manually.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Location error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Widget _buildDetectLocationButton() {
    return InkWell(
      onTap: _isDetectingLocation ? null : _detectLocation,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _locationDetected
              ? const Color(0xFFDCFCE7)
              : AppColors.primaryGold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _locationDetected
                ? const Color(0xFF16A34A)
                : AppColors.primaryGoldDark.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDetectingLocation) ...[
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGoldDark,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Detecting...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGoldDark,
                ),
              ),
            ] else ...[
              Icon(
                _locationDetected ? Icons.check_circle_rounded : Icons.my_location_rounded,
                size: 12,
                color: _locationDetected ? const Color(0xFF16A34A) : AppColors.primaryGoldDark,
              ),
              const SizedBox(width: 4),
              Text(
                _locationDetected ? 'GPS Detected' : '📍 Detect Location',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _locationDetected ? const Color(0xFF16A34A) : AppColors.primaryGoldDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _contactPersonController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  bool _isSendingOtp = false;

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _otpSent = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter an official organization email address first.'),
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    // 1. Check if email is already registered in database
    final existing = await SupabaseService.checkEmailRegistered(email);
    if (existing != null) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _otpSent = false;
      });
      _timer?.cancel();
      _showAlreadyRegisteredDialog(email, existing['role']?.toString());
      return;
    }

    try {
      await SupabaseService.sendEmailOtp(email: email);
      _startCountdown();
      for (final c in _otpControllers) {
        c.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.greenBadgeText,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OTP sent to $email! (Check your Inbox and Spam/Junk folder)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      debugPrint('Provider SignUp sendEmailOtp error: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            err.contains('Database error') || err.contains('unexpected_failure')
                ? 'Supabase Error: Database trigger on auth.users failed. Run supabase/fix_auth_triggers.sql in SQL Editor.'
                : (err.contains('rate limit')
                    ? 'Email rate limit reached. Please wait a minute before requesting another code.'
                    : 'Unable to send OTP: $err'),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _showAlreadyRegisteredDialog(String email, String? registeredRole) async {
    final displayRole = (registeredRole != null && registeredRole.isNotEmpty)
        ? (registeredRole[0].toUpperCase() + registeredRole.substring(1).toLowerCase())
        : 'Provider';

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFD97706),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This email is already registered ($displayRole). Please go to the login page.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                color: Color(0xFFD97706),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Account Already Exists',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF18181B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An account with the email "$email" is already registered on Food Flow ($displayRole).',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF6B7280)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No OTP was sent. Please navigate to the Login page to sign in with this email.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Use Different Email', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(
                    initialSignUp: false,
                    initialRole: UserRole.provider,
                    initialEmail: email,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Go to Login Page'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5BA13),
              foregroundColor: const Color(0xFF18181B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeRegistration() async {
    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final enteredOtp = _otpControllers.map((c) => c.text.trim()).join();
      if (enteredOtp.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
                'Please enter the complete 8-digit OTP code sent to your email.'),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final authRes = await SupabaseService.verifyEmailOtp(
        email: email,
        token: enteredOtp,
      );

      final user = authRes.user ?? SupabaseService.currentUser;
      if (user != null) {
        try {
          await SupabaseService.client.auth.updateUser(UserAttributes(
            data: {
              'role': 'provider',
              'organization_name': _orgNameController.text.trim(),
              'authorized_representative': _contactPersonController.text.trim(),
              'full_name': _contactPersonController.text.trim(),
              'operating_location': _addressController.text.trim(),
            },
          ));
        } catch (_) {}

        await SupabaseService.createProvider(
          userId: user.id,
          email: email,
          organizationName: _orgNameController.text.trim(),
          category: _selectedCategory,
          authorizedRepresentative: _contactPersonController.text.trim(),
          operatingLocation: _addressController.text.trim(),
        );

        await AuthService.instance.fetchProfile(forceRefresh: true);
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.greenBadgeBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.greenBadgeText,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Provider Account Created!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_orgNameController.text} has been registered and verified in Supabase! You can now access your provider dashboard.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DashboardPage(initialRole: 'provider'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Registration error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildStepIndicator(),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _currentStep == 0
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: _buildStepOneOrgDetails(),
                        secondChild: _buildStepTwoVerification(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
              tooltip: 'Back',
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_rounded,
                  color: Colors.black87, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Flow',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'PROVIDER PORTAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGoldKicker,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            if (SupabaseService.isAuthenticated) ...[
              AppDrawer.buildSignOutButton(context),
            ] else ...[
              const Text(
                'Already registered? ',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGoldDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.selectedPillBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded,
                  size: 14, color: AppColors.selectedPillText),
              SizedBox(width: 6),
              Text(
                'Food Donor Registration',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.selectedPillText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sign Up as Food Provider',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Register your culinary facility to direct surplus batches to local verified relief agencies.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepChip(
          index: 0,
          label: 'Organization Profile',
          isActive: _currentStep == 0,
          isCompleted: _currentStep > 0,
        ),
        Container(
          width: 32,
          height: 2,
          color: _currentStep > 0 ? AppColors.primaryGold : AppColors.borderSubtle,
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        _buildStepChip(
          index: 1,
          label: 'Verification',
          isActive: _currentStep == 1,
          isCompleted: false,
        ),
      ],
    );
  }

  Widget _buildStepChip({
    required int index,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    return GestureDetector(
      onTap: () {
        if (index < _currentStep) {
          setState(() => _currentStep = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : (isCompleted ? AppColors.greenBadgeBg : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primaryGold
                : (isCompleted ? AppColors.greenBadgeText : AppColors.borderSubtle),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompleted)
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: AppColors.greenBadgeText)
            else
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryGold : AppColors.borderSubtle,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.black87 : AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive
                    ? AppColors.textPrimary
                    : (isCompleted
                        ? AppColors.greenBadgeText
                        : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 1: ORGANIZATION DETAILS ---
  Widget _buildStepOneOrgDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Provider Establishment Details",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provide official establishment credentials to guarantee food safety compliance.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Organization Name
        _buildFieldLabel("Name of Provider's Organisation *"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _orgNameController,
          validator: (v) => v == null || v.isEmpty ? 'Organization name is required' : null,
          decoration: _inputDecoration(
            hint: 'e.g. Grand Palace Hotel, City Caterers, St. Stephen Mess',
            prefixIcon: Icons.business_rounded,
          ),
        ),
        const SizedBox(height: 16),

        // Establishment Category
        _buildFieldLabel('Provider Category *'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 13.5)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Contact Person & Operating Location Row
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Authorized Representative *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _contactPersonController,
                          decoration: _inputDecoration(
                            hint: 'Full Name',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: _buildFieldLabel('Operating Location / City *'),
                            ),
                            const SizedBox(width: 6),
                            _buildDetectLocationButton(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          decoration: _inputDecoration(
                            hint: 'e.g. New Delhi, Central Zone',
                            prefixIcon: Icons.location_on_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Authorized Representative *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contactPersonController,
                  decoration: _inputDecoration(
                    hint: 'Full Name',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _buildFieldLabel('Operating Location / City *'),
                    ),
                    const SizedBox(width: 6),
                    _buildDetectLocationButton(),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  decoration: _inputDecoration(
                    hint: 'e.g. New Delhi, Central Zone',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Next Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? true) {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Verification',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: VERIFICATION FLOW ---
  Widget _buildStepTwoVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Verification',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Verify your official organization email to activate donor access.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),

        _buildFieldLabel('Official Organization Email *'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hint: 'e.g. manager@hotel.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSendingOtp ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18181B),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _otpSent ? 'Resend' : 'Send Code',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // OTP Input Section (Shows dynamically when OTP is requested)
        if (_otpSent) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.ruleBannerBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderRuleBanner),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enter 8-Digit Verification Code',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textRule,
                      ),
                    ),
                    Text(
                      _resendCountdown > 0
                          ? 'Expires in ${_resendCountdown}s'
                          : 'Code expired',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGoldDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SixDigitOtpInput(
                  controllers: _otpControllers,
                  focusNodes: _otpFocusNodes,
                  activeBorderColor: AppColors.primaryGoldDark,
                  onCompleted: (code) {
                    _completeRegistration();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Action Buttons Row (Back + Submit)
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Edit Details'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _completeRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Submit & Activate Provider Account',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text(
          '© 2025 Food Flow Inc. All rights reserved.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Text('Provider Guidelines',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            Text('Food Safety Verification',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            Text('Help & Support',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}
