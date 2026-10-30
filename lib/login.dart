import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'pages/dashboard.dart';
import 'pages/provider/provider_signup.dart';
import 'pages/receiver/receiver_signup.dart';
import 'pages/volunteer/volunteer_signup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/location_service.dart';
import 'widgets/app_drawer.dart';
import 'widgets/six_digit_otp_input.dart';

// ============================================================================
// 1. BRAND COLORS & CONSTANTS
// ============================================================================

class AppColors {
  // Backgrounds
  static const Color pageBackground = Color(0xFFFBF8F0);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundSelected = Color(0xFFFFFDF8);
  static const Color logoBoxBackground = Color(0xFFFEF9E6);
  static const Color ruleBannerBackground = Color(0xFFFEF9E7);

  // Borders & Accents
  static const Color borderSubtle = Color(0xFFE8E3D7);
  static const Color borderRuleBanner = Color(0xFFF3DE9D);
  static const Color borderDashedLogo = Color(0xFFE4BC4B);
  static const Color primaryGold = Color(0xFFF5BA13);
  static const Color primaryGoldDark = Color(0xFFD99F05);

  // Typography
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textGoldKicker = Color(0xFF8B670A);
  static const Color textRule = Color(0xFF7A5907);
  static const Color textLogo = Color(0xFF6B4B03);

  // Badges
  static const Color greenBadgeBg = Color(0xFFDCFCE7);
  static const Color greenBadgeText = Color(0xFF15803D);
  static const Color liveSyncBg = Color(0xFFDFF5EA);
  static const Color liveSyncText = Color(0xFF1B7A4C);

  static const Color peachBadgeBg = Color(0xFFFEF3C7);
  static const Color peachBadgeText = Color(0xFF92400E);

  static const Color slateBadgeBg = Color(0xFFF1F5F9);
  static const Color slateBadgeText = Color(0xFF475569);

  static const Color selectedPillBg = Color(0xFFFDECB8);
  static const Color selectedPillText = Color(0xFF8A5E04);

  static const Color segmentedControlBg = Color(0xFFEDE9E0);
}

// ============================================================================
// 2. DATA MODELS
// ============================================================================

enum UserRole {
  provider,
  receiver,
  volunteer,
}

class RoleBadge {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const RoleBadge({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });
}

class RoleItem {
  final UserRole role;
  final String title;
  final String description;
  final List<RoleBadge> badges;

  const RoleItem({
    required this.role,
    required this.title,
    required this.description,
    required this.badges,
  });
}

// ============================================================================
// 3. UI COMPONENTS & CUSTOM PAINTERS
// ============================================================================

/// Custom painter to draw the dashed golden border around the logo box
class DashedRoundedRectanglePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashGap;

  const DashedRoundedRectanglePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 12.0,
    this.dashWidth = 4.5,
    this.dashGap = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path, dashWidth, dashGap);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashGap) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        dest.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DashedRoundedRectanglePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}

/// The App Logo Box with dashed border and tray/downward-arrow icon
class FoodFlowLogoBox extends StatelessWidget {
  const FoodFlowLogoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DashedRoundedRectanglePainter(
        color: AppColors.borderDashedLogo,
        radius: 12,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: 170,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.logoBoxBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Food donation tray icon with downward arrow
            SizedBox(
              width: 32,
              height: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 2,
                    child: Container(
                      width: 28,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.textLogo,
                          width: 2,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 32,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textLogo,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 7,
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      size: 14,
                      color: AppColors.textLogo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'APP LOGO',
              style: TextStyle(
                color: AppColors.textLogo,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Left side branding & Platform Features Section
class BrandHeaderSection extends StatelessWidget {
  const BrandHeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App Logo
        const Center(
          child: FoodFlowLogoBox(),
        ),
        const SizedBox(height: 20),

        // Brand Title
        const Center(
          child: Text(
            'Food Flow',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        const Center(
          child: Text(
            'Surplus Food Rescue & Logistics Redistribution Platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Features Card
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Features Card Header
              const Text(
                'FEATURES OF PLATFORM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textGoldKicker,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Feature 1: Real-Time Dispatch
              _buildFeatureItem(
                icon: Icons.access_time_rounded,
                title: 'Real-Time Dispatch: ',
                description:
                    'Instant matchmaking of surplus food with nearby recipients and pickup support.',
              ),
              const SizedBox(height: 12),

              // Feature 2: Verified Partners
              _buildFeatureItem(
                icon: Icons.verified_user_outlined,
                title: 'Verified Partners: ',
                description:
                    'Verification checks for donors, NGOs, shelters and participating volunteers.',
              ),
              const SizedBox(height: 12),

              // Feature 3: Transparent Tracking
              _buildFeatureItem(
                icon: Icons.alt_route_rounded,
                title: 'Transparent Tracking: ',
                description:
                    'Track the rescue journey from food listing to pickup and final delivery.',
              ),
              const SizedBox(height: 12),

              // Feature 4: Smart Location Matching
              _buildFeatureItem(
                icon: Icons.location_on_outlined,
                title: 'Smart Location Matching: ',
                description:
                    'Match available food with suitable nearby recipients using location, food type and urgency.',
              ),
              const SizedBox(height: 12),

              // Feature 5: Impact Tracking
              _buildFeatureItem(
                icon: Icons.eco_outlined,
                title: 'Impact Tracking: ',
                description:
                    'Measure meals rescued, food saved, people served and successful redistributions.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 17,
            color: const Color(0xFFC79213),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Segmented Switch between Sign In and Sign Up
class SegmentedAuthTab extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onTabChanged;

  const SegmentedAuthTab({
    super.key,
    required this.isSignUp,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.segmentedControlBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Sign In',
              isSelected: !isSignUp,
              onTap: () => onTabChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              title: 'Sign Up',
              isSelected: isSignUp,
              onTap: () => onTabChanged(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Role selection card (Provider, Receiver, Volunteer)
class RoleCardWidget extends StatelessWidget {
  final RoleItem data;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleCardWidget({
    super.key,
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cardBackgroundSelected
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Radio Circle
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _buildRadio(isSelected),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Badges Row
                  Row(
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Wrap(
                              spacing: 6,
                              children: data.badges
                                  .take(data.badges.length > 1 ? 1 : 0)
                                  .map((b) => _buildBadge(b))
                                  .toList(),
                            ),
                            if (data.badges.isNotEmpty)
                              _buildBadge(data.badges.last),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    data.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(bool selected) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primaryGold : const Color(0xFFCBD5E1),
          width: 2.0,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBadge(RoleBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badge.text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badge.textColor,
        ),
      ),
    );
  }
}

// ============================================================================
// 4. MAIN LOGIN PAGE WIDGET
// ============================================================================

class LoginPage extends StatefulWidget {
  final bool initialSignUp;
  final UserRole? initialRole;
  final String? initialEmail;
  const LoginPage({
    super.key,
    this.initialSignUp = true,
    this.initialRole,
    this.initialEmail,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late bool _isSignUp;
  UserRole _selectedRole = UserRole.provider;

  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;
  bool _isSigningIn = false;
  bool _otpSent = false;
  bool _isSendingOtp = false;
  int _otpCountdown = 60;
  Timer? _otpTimer;
  bool _isDetectingLocation = false;
  bool _locationDetected = false;
  LatLng? _detectedCoords;

  final List<RoleItem> _roles = const [
    RoleItem(
      role: UserRole.provider,
      title: '1. Provider',
      description:
          'Hostels, Caterers, Restaurants/Hotels dispatching surplus culinary batches directly.',
      badges: [
        RoleBadge(
          text: 'Main',
          backgroundColor: AppColors.greenBadgeBg,
          textColor: AppColors.greenBadgeText,
        ),
        RoleBadge(
          text: 'Supply Side',
          backgroundColor: AppColors.peachBadgeBg,
          textColor: AppColors.peachBadgeText,
        ),
      ],
    ),
    RoleItem(
      role: UserRole.receiver,
      title: '2. Receiver',
      description:
          'NGOs, Shelters, and Personal Donations handling vetted distribution to people in need.',
      badges: [
        RoleBadge(
          text: 'Demand Side',
          backgroundColor: AppColors.slateBadgeBg,
          textColor: AppColors.slateBadgeText,
        ),
      ],
    ),
    RoleItem(
      role: UserRole.volunteer,
      title: '3. Volunteer',
      description:
          'Pickup couriers and field dispatchers facilitating timely micro-transit handover.',
      badges: [
        RoleBadge(
          text: 'Logistics',
          backgroundColor: AppColors.slateBadgeBg,
          textColor: AppColors.slateBadgeText,
        ),
      ],
    ),
  ];

  String get _roleName {
    switch (_selectedRole) {
      case UserRole.provider:
        return 'Provider';
      case UserRole.receiver:
        return 'Receiver';
      case UserRole.volunteer:
        return 'Volunteer';
    }
  }

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
    if (widget.initialRole != null) {
      _selectedRole = widget.initialRole!;
    } else if (kIsWeb && Uri.base.queryParameters.containsKey('role')) {
      final r = Uri.base.queryParameters['role']?.toLowerCase();
      final parsedRole = UserRole.values.asNameMap()[r];
      if (parsedRole != null) {
        _selectedRole = parsedRole;
      }
    }
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    final initialLoc = LocationService.currentProviderLocation;
    _locationController = TextEditingController(
      text: initialLoc?.displayAddress ?? '',
    );
    if (initialLoc != null) {
      _locationDetected = true;
      _detectedCoords = LatLng(initialLoc.latitude, initialLoc.longitude);
    }
    _otpControllers = List.generate(8, (_) => TextEditingController());
    _otpFocusNodes = List.generate(8, (_) => FocusNode());

    // Auto-detect user's real location on landing if not yet known
    if (initialLoc == null || !LocationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_locationController.text.trim().isEmpty || !LocationService.hasRealLocation)) {
          _autoDetectLocationSilently();
        }
      });
    }

    if (SupabaseService.isInitialized) {
      if (SupabaseService.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final user = SupabaseService.currentUser;
            if (user != null) {
              _routeAuthenticatedUser(user, defaultRole: _roleName.toLowerCase());
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardPage()),
              );
            }
          }
        });
      }
      _authSubscription =
          SupabaseService.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn && mounted) {
          final user = data.session?.user ?? SupabaseService.currentUser;
          if (user != null) {
            _routeAuthenticatedUser(user, defaultRole: _roleName.toLowerCase());
          }
        }
      });
    }
  }

  String _roleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'receiver':
        return 'Receiver';
      case 'volunteer':
        return 'Volunteer';
      case 'provider':
      default:
        return 'Provider';
    }
  }

  Future<void> _routeAuthenticatedUser(User user, {String? defaultRole}) async {
    final effectiveDefaultRole = defaultRole ?? _selectedRole.name;

    // 1. Resolve role from Supabase checking metadata, volunteers, receivers, profiles tables
    String resolvedRole = await SupabaseService.resolveUserRole(
      email: user.email ?? '',
      fallbackRole: effectiveDefaultRole,
    );

    // 2. Fetch or heal verified profile from Supabase with the resolved role
    final profile = await AuthService.instance.fetchProfile(forceRefresh: true);
    if (profile != null && profile.role.isNotEmpty && profile.role != 'provider' && resolvedRole == 'provider') {
      resolvedRole = profile.role;
    }

    // 3. Persist or restore user's real location with profile context
    await _persistLocationOnSignIn(profile: profile);

    await SupabaseService.syncUserProfile(
      user,
      resolvedRole,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Text(
          'Verified as ${_roleDisplayName(resolvedRole)}. Opening your portal.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardPage(initialRole: resolvedRole),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _locationController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _otpTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoDetectLocationSilently() async {
    try {
      final result = await LocationService.detectCurrentLocation();
      if (result != null && mounted) {
        setState(() {
          _locationDetected = true;
          _detectedCoords = LatLng(result.latitude, result.longitude);
          if (_locationController.text.trim().isEmpty) {
            _locationController.text = result.displayAddress;
          }
        });
        LocationService.setProviderLocation(result);
      }
    } catch (_) {}
  }

  Future<void> _detectLocationOnLogin() async {
    setState(() => _isDetectingLocation = true);
    try {
      final result = await LocationService.detectCurrentLocation();
      if (result != null && mounted) {
        setState(() {
          _locationDetected = true;
          _detectedCoords = LatLng(result.latitude, result.longitude);
          _locationController.text = result.displayAddress;
        });
        LocationService.setProviderLocation(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.greenBadgeText,
            content: Text(
              '📍 Real location detected: ${_locationController.text}',
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

  Future<void> _persistLocationOnSignIn({UserProfile? profile}) async {
    final locText = _locationController.text.trim();

    // 1. Fresh GPS coordinates detected in this session
    if (_detectedCoords != null) {
      final effectiveName = locText.isNotEmpty
          ? locText
          : (LocationService.currentProviderLocation?.shortLocation ??
              LocationService.currentProviderLocation?.formattedAddress ??
              'Detected Location');

      LocationService.setProviderLocationCoords(
        locationName: effectiveName,
        latitude: _detectedCoords!.latitude,
        longitude: _detectedCoords!.longitude,
        shortLocation: LocationService.currentProviderLocation?.shortLocation ?? effectiveName,
      );

      if (SupabaseService.isAuthenticated) {
        try {
          await SupabaseService.updateUserLocation(
            locationName: effectiveName,
            latitude: _detectedCoords!.latitude,
            longitude: _detectedCoords!.longitude,
          );
        } catch (_) {}
      }
      return;
    }

    // 2. User explicitly typed a custom location name
    if (locText.isNotEmpty) {
      final existingLoc = LocationService.currentProviderLocation;
      final lat = existingLoc?.latitude ?? 12.9784;
      final lng = existingLoc?.longitude ?? 77.6408;

      LocationService.setProviderLocationCoords(
        locationName: locText,
        latitude: lat,
        longitude: lng,
        shortLocation: locText,
      );

      if (SupabaseService.isAuthenticated) {
        try {
          await SupabaseService.updateUserLocation(
            locationName: locText,
            latitude: lat,
            longitude: lng,
          );
        } catch (_) {}
      }
      return;
    }

    // 3. User didn't type anything. Restore saved location from database profile
    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final savedLoc = (profile?.operatingLocation != null && profile!.operatingLocation!.trim().isNotEmpty)
        ? profile.operatingLocation!.trim()
        : (meta['operating_location'] as String? ?? '');

    if (savedLoc.isNotEmpty) {
      final lat = (meta['latitude'] as num?)?.toDouble() ?? 12.9784;
      final lng = (meta['longitude'] as num?)?.toDouble() ?? 77.6408;

      LocationService.setProviderLocationCoords(
        locationName: savedLoc,
        latitude: lat,
        longitude: lng,
        shortLocation: savedLoc,
      );
      return;
    }

    // 4. No location saved or typed: Quick auto-detection
    final detected = await LocationService.detectCurrentLocation();
    if (detected != null) {
      LocationService.setProviderLocation(detected);
      if (SupabaseService.isAuthenticated) {
        try {
          await SupabaseService.updateUserLocation(
            locationName: detected.shortLocation ?? detected.formattedAddress,
            latitude: detected.latitude,
            longitude: detected.longitude,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _sendLoginOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter your email address first.'),
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    // If currently in sign up mode, check if email is already registered
    if (_isSignUp) {
      final existing = await SupabaseService.checkEmailRegistered(email);
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _isSendingOtp = false;
          _isSignUp = false;
          _otpSent = false;
        });
        final parsedRole = UserRole.values.asNameMap()[existing['role']?.toString().toLowerCase()];
        if (parsedRole != null) _selectedRole = parsedRole;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD97706),
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'An account with $email is already registered. Switched to Sign In mode.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
    } else {
      // In Sign In mode: verify that an account exists for this email
      final existing = await SupabaseService.checkEmailRegistered(email);
      if (existing == null) {
        if (!mounted) return;
        setState(() => _isSendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD97706),
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No Food Flow account found for $email. Please switch to Sign Up to create your account.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      final parsedRole = UserRole.values.asNameMap()[existing['role']?.toString().toLowerCase()];
      if (parsedRole != null) _selectedRole = parsedRole;
    }

    try {
      await SupabaseService.sendEmailOtp(email: email);
      _otpTimer?.cancel();
      for (final c in _otpControllers) {
        c.clear();
      }
      setState(() {
        _otpSent = true;
        _otpCountdown = 60;
      });
      _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_otpCountdown > 0) {
          setState(() => _otpCountdown--);
        } else {
          timer.cancel();
        }
      });
      if (!mounted) return;
      _otpFocusNodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.greenBadgeText,
          content: Text(
            '6-digit OTP sent to $email! (Check your Inbox and Spam/Junk folder)',
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
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyAndSignInOtp([String? explicitOtp]) async {
    final email = _emailController.text.trim();
    final otp = (explicitOtp != null && explicitOtp.isNotEmpty)
        ? explicitOtp
        : _otpControllers.map((c) => c.text.trim()).join();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter your email address.'),
        ),
      );
      return;
    }

    if (otp.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter the complete 8-digit OTP code.'),
        ),
      );
      return;
    }

    setState(() => _isSigningIn = true);

    try {
      final authRes = await SupabaseService.verifyEmailOtp(
        email: email,
        token: otp,
      );

      if (authRes.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.greenBadgeText,
            content: Text(
              'Verified & signed in successfully via Supabase!',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
        await _routeAuthenticatedUser(authRes.user!, defaultRole: _roleName.toLowerCase());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Verification failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          tooltip: 'Back to Home',
        ),
        actions: [
          if (SupabaseService.isAuthenticated) ...[
            AppDrawer.buildSignOutButton(context),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 780;

                    if (isWide) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Column (Branding & Features)
                            const Expanded(
                              flex: 9,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(40, 44, 36, 44),
                                child: BrandHeaderSection(),
                              ),
                            ),

                            // Vertical Divider
                            Container(
                              width: 1.2,
                              color: AppColors.borderSubtle,
                            ),

                            // Right Column (Profile Setup / Authentication)
                            Expanded(
                              flex: 11,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(36, 44, 40, 44),
                                child: _buildRightPanel(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Mobile / single column layout
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const BrandHeaderSection(),
                          const SizedBox(height: 32),
                          const Divider(
                            color: AppColors.borderSubtle,
                            thickness: 1.2,
                          ),
                          const SizedBox(height: 24),
                          _buildRightPanel(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Kicker
        const Center(
          child: Text(
            'PROFILE SETUP',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textGoldKicker,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Welcome Headline
        const Center(
          child: Text(
            'Welcome to Food Flow',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        const Center(
          child: Text(
            'Seamless authentication and specialized access tier allocation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Segmented Control (Sign In vs Sign Up)
        SegmentedAuthTab(
          isSignUp: _isSignUp,
          onTabChanged: (val) {
            setState(() {
              _isSignUp = val;
            });
          },
        ),
        const SizedBox(height: 20),

        if (_isSignUp) ...[
          // Select Role Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'SELECT ROLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // "Selected: Provider" Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.selectedPillBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Selected: $_roleName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.selectedPillText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Role Option Cards
          ..._roles.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RoleCardWidget(
                data: item,
                isSelected: _selectedRole == item.role,
                onTap: () {
                  setState(() {
                    _selectedRole = item.role;
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Widget targetPage;
                switch (_selectedRole) {
                  case UserRole.provider:
                    targetPage = const ProviderSignUpPage();
                    break;
                  case UserRole.receiver:
                    targetPage = const ReceiverSignUpPage();
                    break;
                  case UserRole.volunteer:
                    targetPage = const VolunteerSignUpPage();
                    break;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => targetPage),
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
              child: Text(
                'Continue with $_roleName',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ] else ...[
          // Sign In Form
          _buildSignInForm(),
        ],
      ],
    );
  }

  String get _locationFieldLabel {
    switch (_selectedRole) {
      case UserRole.provider:
        return 'Operating / Kitchen Location';
      case UserRole.receiver:
        return 'Shelter / Relief Distribution Address';
      case UserRole.volunteer:
        return 'Current Transit / Dispatch Area';
    }
  }

  String get _locationFieldHint {
    switch (_selectedRole) {
      case UserRole.provider:
        return 'e.g. Indiranagar Kitchen #2, Bengaluru';
      case UserRole.receiver:
        return 'e.g. Hope Relief Center, Koramangala';
      case UserRole.volunteer:
        return 'e.g. Central Bengaluru Logistics Hub';
    }
  }

  Widget _buildRoleInfoBanner() {
    IconData icon;
    String title;
    String subtitle;
    Color accentColor;
    Color bgLight;

    switch (_selectedRole) {
      case UserRole.provider:
        icon = Icons.restaurant_rounded;
        title = 'Food Provider Portal';
        subtitle = 'Hotels, Caterers & Hostels dispatching verified surplus culinary meals.';
        accentColor = const Color(0xFFD97706);
        bgLight = const Color(0xFFFEF3C7);
        break;
      case UserRole.receiver:
        icon = Icons.volunteer_activism_rounded;
        title = 'NGO Receiver Portal';
        subtitle = 'Shelters, Food Banks & Orphanages requesting & receiving meal donations.';
        accentColor = const Color(0xFF059669);
        bgLight = const Color(0xFFD1FAE5);
        break;
      case UserRole.volunteer:
        icon = Icons.two_wheeler_rounded;
        title = 'Volunteer Courier Portal';
        subtitle = 'Dispatch riders & transit volunteers executing rapid pickup and delivery.';
        accentColor = const Color(0xFF2563EB);
        bgLight = const Color(0xFFDBEAFE);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleAccountRuleBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 15, color: Color(0xFF475569)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '1 Email = 1 Role Account. Accounts strictly route to their registered tier upon sign in.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.initialRole != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIGN IN PORTAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.selectedPillBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Portal: $_roleName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.selectedPillText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRoleInfoBanner(),
          const SizedBox(height: 10),
        ],

        // Strict Single-Account Role Banner
        _buildSingleAccountRuleBanner(),
        const SizedBox(height: 16),

        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
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
        const SizedBox(height: 16),

        // Operating / Kitchen / Shelter Location Row with GPS Detection Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: _selectedRole == UserRole.provider
                        ? AppColors.primaryGoldDark
                        : (_selectedRole == UserRole.receiver
                            ? const Color(0xFF059669)
                            : const Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _locationFieldLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _isDetectingLocation ? null : _detectLocationOnLogin,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGoldDark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Detecting...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGoldDark,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        _locationDetected ? Icons.check_circle_rounded : Icons.my_location_rounded,
                        size: 13,
                        color: _locationDetected ? const Color(0xFF16A34A) : AppColors.primaryGoldDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _locationDetected ? 'GPS Detected' : '📍 Detect Location',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _locationDetected ? const Color(0xFF16A34A) : AppColors.primaryGoldDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _locationController,
          onChanged: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              LocationService.setProviderLocationCoords(
                locationName: trimmed,
                latitude: _detectedCoords?.latitude ?? 12.9784,
                longitude: _detectedCoords?.longitude ?? 77.6408,
              );
            }
          },
          decoration: InputDecoration(
            hintText: _locationFieldHint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(Icons.storefront_rounded, size: 18, color: AppColors.textSecondary),
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
        const SizedBox(height: 16),

        // Email OTP Flow
        if (!_otpSent) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSendingOtp ? null : _sendLoginOtp,
              icon: _isSendingOtp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSendingOtp ? 'Sending code...' : 'Send Login Code',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18181B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ] else ...[
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
                            size: 17, color: AppColors.primaryGoldDark),
                        SizedBox(width: 6),
                        Text(
                          'Enter 8-Digit Code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textRule,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _otpCountdown > 0
                          ? 'Expires in ${_otpCountdown}s'
                          : 'Code expired',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGoldDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Code sent to ${_emailController.text}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SixDigitOtpInput(
                  controllers: _otpControllers,
                  focusNodes: _otpFocusNodes,
                  activeBorderColor: AppColors.primaryGoldDark,
                  onCompleted: (code) {
                    _verifyAndSignInOtp(code);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _otpCountdown == 0 && !_isSendingOtp
                          ? _sendLoginOtp
                          : null,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: Text(
                        _otpCountdown > 0
                            ? 'Resend in ${_otpCountdown}s'
                            : 'Resend Code',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGoldDark,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _otpSent = false);
                      },
                      child: const Text(
                        'Change Email',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSigningIn ? null : () => _verifyAndSignInOtp(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSigningIn
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                  : const Text(
                      'Verify & Sign In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF3DE9D)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF92400E)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: Check your Spam or Junk folder if the OTP email does not appear in Inbox within 1 minute.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
