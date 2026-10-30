import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../login.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/six_digit_otp_input.dart';
import '../dashboard.dart';

class VolunteerSignUpPage extends StatefulWidget {
  const VolunteerSignUpPage({super.key});

  @override
  State<VolunteerSignUpPage> createState() => _VolunteerSignUpPageState();
}

class _VolunteerSignUpPageState extends State<VolunteerSignUpPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  int _currentStep = 0;
  String _transitMode = 'Two-Wheeler';
  bool _otpSent = false;
  int _resendCountdown = 60;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _isDetectingLocation = false;
  bool _locationDetected = false;

  final List<Map<String, dynamic>> _transitOptions = [
    {
      'title': 'Two-Wheeler',
      'subtitle': 'Best for <15 parcels',
      'icon': Icons.two_wheeler_rounded,
    },
    {
      'title': 'Car / Van',
      'subtitle': 'Best for <50 parcels',
      'icon': Icons.directions_car_filled_rounded,
    },
    {
      'title': 'Semi Truck',
      'subtitle': 'Capacity 50–300 parcels',
      'icon': Icons.local_shipping_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    final initialLoc = LocationService.currentProviderLocation;
    _locationController = TextEditingController(
      text: initialLoc?.displayAddress ?? '',
    );
    if (initialLoc != null) {
      _locationDetected = true;
    }
    _phoneController = TextEditingController();
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
    _emailController = TextEditingController();
    _otpControllers = List.generate(8, (_) => TextEditingController());
    _otpFocusNodes = List.generate(8, (_) => FocusNode());

    if (initialLoc == null || !LocationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _locationController.text.trim().isEmpty) {
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
          _locationController.text = result.displayAddress;
        });
        LocationService.setProviderLocation(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            content: Text(
              '📍 Location detected: ${_locationController.text}',
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
    _nameController.dispose();
    _locationController.dispose();
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
      for (final c in _otpControllers) {
        c.clear();
      }
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

      _otpFocusNodes[0].requestFocus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.greenBadgeText,
          content: Text(
            '8-digit OTP sent to $email! (Check Inbox & Spam folder)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Supabase OTP Error: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _showAlreadyRegisteredDialog(String email, String? registeredRole) async {
    final displayRole = (registeredRole != null && registeredRole.isNotEmpty)
        ? (registeredRole[0].toUpperCase() + registeredRole.substring(1).toLowerCase())
        : 'Volunteer';

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
                    initialRole: UserRole.volunteer,
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter your full name.'),
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter your contact mobile number.'),
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter your email address.'),
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
        await SupabaseService.createVolunteer(
          userId: user.id,
          email: email,
          fullName: name,
          governmentId: '',
          transitMode: _transitMode,
          phone: phone,
          operatingLocation: _locationController.text.trim(),
        );
        try {
          await AuthService.instance.fetchProfile(forceRefresh: true);
        } catch (_) {}
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
                  Icons.electric_moped_rounded,
                  color: AppColors.greenBadgeText,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Volunteer Dispatch Approved!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome aboard, ${_nameController.text}! Your transit profile ($_transitMode) has been verified and registered in Supabase. You can now claim surplus transport tasks.',
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
                            const DashboardPage(initialRole: 'volunteer'),
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
                    'Open Volunteer Hub',
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
                  const SizedBox(height: 24),
                  _buildStepIndicator(),
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
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _currentStep == 0
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: _buildStepOnePersonalDetails(),
                        secondChild: _buildStepTwoVerification(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '© 2025 Food Flow Humanitarian Platform • Verified Food Rescue Standards',
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

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepChip(
          index: 0,
          label: 'Personal Details',
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

  // --- STEP 1: PERSONAL DETAILS ---
  Widget _buildStepOnePersonalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Full Name (as per official ID) *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameController,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Please enter your full name'
              : null,
          decoration: _inputDecoration(
            hint: 'e.g. John Doe',
            icon: Icons.person_rounded,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _buildLabel('Transit Operating Base / City *'),
            ),
            const SizedBox(width: 6),
            _buildDetectLocationButton(),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            hintText: 'e.g. Indiranagar Logistics Hub, Bengaluru',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.primaryGold, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Contact Mobile Number *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Please enter contact mobile number';
            }
            if (v.trim().length != 10) {
              return 'Mobile number must be exactly 10 digits';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: '9876543210',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android_rounded,
                      size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    '+91',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '|',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            counterText: '${_phoneController.text.length}/10',
            counterStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _phoneController.text.length == 10
                  ? AppColors.greenBadgeText
                  : AppColors.textSecondary,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide:
                  const BorderSide(color: AppColors.primaryGold, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildLabel('Transit & Delivery Mode *'),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return GridView.count(
              crossAxisCount: isWide ? 3 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 12,
              childAspectRatio: isWide ? 2.5 : 4.0,
              children: _transitOptions.map((opt) {
                final isSelected = _transitMode == opt['title'];
                return GestureDetector(
                  onTap: () => setState(() => _transitMode = opt['title']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.cardBackgroundSelected
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGold
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.0 : 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            opt['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Colors.black87
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                opt['subtitle'] as String,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: AppColors.primaryGoldDark),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 28),

        // Continue to Verification Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Please enter your full name.'),
                  ),
                );
                return;
              }
              if (_phoneController.text.trim().length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Contact mobile number must be exactly 10 digits.'),
                  ),
                );
                return;
              }
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
        _buildLabel('Volunteer Email Address *'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hint: 'volunteer@example.com',
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
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_otpSent ? 'Resend' : 'Send Code'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Interactive OTP entry
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
                    const Row(
                      children: [
                        Icon(Icons.mark_email_read_rounded,
                            color: AppColors.primaryGoldDark,
                            size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Enter 8-Digit Verification Code',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textRule,
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
                    _submitRegistration();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Submit Button
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Verify & Complete Volunteer Registration',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _currentStep = 0),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back to Personal Details'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
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
              child: const Icon(Icons.electric_moped_rounded,
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
                  'VOLUNTEER PORTAL',
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(
                        initialSignUp: false,
                        initialRole: UserRole.volunteer,
                      ),
                    ),
                  );
                },
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
    return const Column(
      children: [
        Text(
          'Sign Up as Food Flow Volunteer',
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
          'Pick up surplus culinary batches from donors and transport them to verified shelters.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
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
