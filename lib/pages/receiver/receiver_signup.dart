import 'dart:async';
import 'package:flutter/material.dart';
import '../../login.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/six_digit_otp_input.dart';
import '../dashboard.dart';

class ReceiverSignUpPage extends StatefulWidget {
  const ReceiverSignUpPage({super.key});

  @override
  State<ReceiverSignUpPage> createState() => _ReceiverSignUpPageState();
}

class _ReceiverSignUpPageState extends State<ReceiverSignUpPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _orgNameController;
  late final TextEditingController _headPersonController;
  late final TextEditingController _serviceAreaController;
  late final TextEditingController _capacityController;
  late final TextEditingController _emailController;

  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  String _selectedCategory = 'NGO';
  bool _otpSent = false;
  int _resendCountdown = 45;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _isDetectingLocation = false;
  bool _locationDetected = false;

  final List<String> _categories = [
    'NGO',
    'Shelter Home',
    'Community Kitchen',
    'Orphanage / Senior Care',
    'Neighborhood Food Pantry',
  ];

  @override
  void initState() {
    super.initState();
    _orgNameController = TextEditingController();
    _headPersonController = TextEditingController();
    final initialLoc = LocationService.currentProviderLocation;
    _serviceAreaController = TextEditingController(
      text: initialLoc?.displayAddress ?? '',
    );
    if (initialLoc != null) {
      _locationDetected = true;
    }
    _capacityController = TextEditingController();
    _emailController = TextEditingController();
    _otpControllers = List.generate(8, (_) => TextEditingController());
    _otpFocusNodes = List.generate(8, (_) => FocusNode());

    if (initialLoc == null || !LocationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _serviceAreaController.text.trim().isEmpty) {
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
          _serviceAreaController.text = result.displayAddress;
        });
        LocationService.setProviderLocation(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            content: Text(
              '📍 Location detected: ${_serviceAreaController.text}',
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
    _headPersonController.dispose();
    _serviceAreaController.dispose();
    _capacityController.dispose();
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

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter an email address first.'),
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
      for (final c in _otpControllers) {
        c.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.greenBadgeText,
          content: Text(
            'OTP sent to $email! (Check your Inbox and Spam/Junk folder)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      debugPrint('Receiver SignUp sendEmailOtp error: $err');
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
        : 'Receiver';

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
                    initialRole: UserRole.receiver,
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

  Future<void> _submitRegistration() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter an official representative email.'),
        ),
      );
      return;
    }

    final enteredOtp = _otpControllers.map((c) => c.text.trim()).join();
    if (enteredOtp.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter the complete 8-digit OTP code.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authRes = await SupabaseService.verifyEmailOtp(
        email: email,
        token: enteredOtp,
      );

      final user = authRes.user ?? SupabaseService.currentUser;
      if (user != null) {
        await SupabaseService.createReceiver(
          userId: user.id,
          email: email,
          organizationName: _orgNameController.text.trim(),
          category: _selectedCategory,
          dailyIntakeCapacity: _capacityController.text.trim().isNotEmpty
              ? _capacityController.text.trim()
              : '200 meals/day',
          representative: _headPersonController.text.trim(),
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
                  Icons.favorite_rounded,
                  color: AppColors.greenBadgeText,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Receiver Verified & Active!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_orgNameController.text} has been registered and verified in Supabase! You will receive notifications when surplus food batches match your capacity.',
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
                            const DashboardPage(initialRole: 'receiver'),
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
                    'Proceed to Relief Hub',
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
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle, width: 1.2),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Organization Details
                          const Row(
                            children: [
                              Icon(Icons.diversity_1_rounded,
                                  color: AppColors.primaryGoldDark, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '1. Receiver Identity & Relief Capacity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Please provide verifiable credentials for relief distribution & hygiene certification.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Org Name
                          _buildLabel("Name of Receiver's Organization *"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _orgNameController,
                            decoration: _inputDecoration(
                              hint: 'e.g. St. Jude Shelter, Community Kitchen, Sunrise Trust',
                              icon: Icons.foundation_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category & Capacity Row
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 580;
                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Receiver Category *'),
                                          const SizedBox(height: 6),
                                          _buildDropdown(
                                            value: _selectedCategory,
                                            items: _categories,
                                            onChanged: (v) =>
                                                setState(() => _selectedCategory = v!),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Daily Meal Intake Capacity *'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _capacityController,
                                            keyboardType: TextInputType.text,
                                            decoration: _inputDecoration(
                                              hint: 'e.g. 200 meals/day',
                                              icon: Icons.restaurant_menu_rounded,
                                            ),
                                            validator: (v) => (v == null || v.trim().isEmpty)
                                                ? 'Please enter daily meal capacity'
                                                : null,
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
                                  _buildLabel('Receiver Category *'),
                                  const SizedBox(height: 6),
                                  _buildDropdown(
                                    value: _selectedCategory,
                                    items: _categories,
                                    onChanged: (v) =>
                                        setState(() => _selectedCategory = v!),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Daily Meal Intake Capacity *'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _capacityController,
                                    keyboardType: TextInputType.text,
                                    decoration: _inputDecoration(
                                      hint: 'e.g. 200 meals/day',
                                      icon: Icons.restaurant_menu_rounded,
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Please enter daily meal capacity'
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: _buildLabel('Distribution / Shelter Location *'),
                              ),
                              const SizedBox(width: 6),
                              _buildDetectLocationButton(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _serviceAreaController,
                            decoration: _inputDecoration(
                              hint: 'e.g. South District, Community Kitchen 4, Bengaluru',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Divider(color: AppColors.borderSubtle),
                          const SizedBox(height: 20),

                          // Section 2: Verification
                          const Row(
                            children: [
                              Icon(Icons.verified_user_rounded,
                                  color: AppColors.primaryGoldDark, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '2. Authorized Representative Verification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Verify your organization email address with a secure one-time passcode.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Official Representative Email *'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration(
                                    hint: 'receiver@organization.org',
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isSendingOtp ? null : _sendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF18181B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(_otpSent ? 'Resend' : 'Send Code'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Dynamic OTP Code Display
                          if (_otpSent) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.greenBadgeBg.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.greenBadgeText
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded,
                                              color: AppColors.greenBadgeText,
                                              size: 16),
                                          SizedBox(width: 6),
                                          Text(
                                            'Enter 8-Digit Verification Code',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.greenBadgeText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _resendCountdown > 0
                                            ? 'Expires in ${_resendCountdown}s'
                                            : 'Code expired',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SixDigitOtpInput(
                                    controllers: _otpControllers,
                                    focusNodes: _otpFocusNodes,
                                    activeBorderColor: AppColors.greenBadgeText,
                                    onCompleted: (code) {
                                      _submitRegistration();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Submit Action
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _submitRegistration,
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Verify & Complete NGO Registration',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Food Flow Relief • Verified Receiver Portal • Zero Food Waste Mission',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
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
              onPressed: () => Navigator.pop(context),
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
              child: const Icon(Icons.volunteer_activism_rounded,
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
                  'RECEIVER PORTAL',
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
                  'Log In',
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
    return const Column(
      children: [
        Text(
          'Sign Up as Relief Receiver',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Register your shelter or charity to connect with hot surplus food from verified kitchens.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }


  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items
              .map((it) => DropdownMenuItem(
                    value: it,
                    child: Text(it, style: const TextStyle(fontSize: 13.5)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
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
}
