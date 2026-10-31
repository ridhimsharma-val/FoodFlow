import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../login.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/brand_logo.dart';
import 'provider/provider_dashboard.dart';
import 'receiver/receiver_dashboard.dart';
import 'volunteer/volunteer_dashboard.dart';

class DashboardPage extends StatefulWidget {
  final String? initialRole;

  const DashboardPage({super.key, this.initialRole});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late String _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole ?? 'provider';
    if (kIsWeb && Uri.base.queryParameters.containsKey('role')) {
      final r = Uri.base.queryParameters['role']?.toLowerCase();
      if (r == 'receiver' || r == 'volunteer' || r == 'provider') {
        _currentRole = r!;
      }
    }
    _enforceVerifiedRole();
  }

  Future<void> _enforceVerifiedRole() async {
    if (!SupabaseService.isAuthenticated) return;
    try {
      final profile = await AuthService.instance.fetchProfile();
      if (profile != null && mounted) {
        if (profile.role != _currentRole) {
          setState(() {
            _currentRole = profile.role;
          });
        }
      }
    } catch (_) {}
  }


  Future<void> _confirmLogOutToSwitch(String targetRole) async {
    final roleTitle = targetRole == 'receiver'
        ? 'Receiver (NGO & Shelters)'
        : (targetRole == 'volunteer' ? 'Volunteer Rescue Squad' : 'Food Provider');

    if (targetRole == _currentRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          content: Text('You are already actively using the $roleTitle Portal.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Log Out to Switch Role?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Each Food Flow account is bound to a single verified role (1 Email = 1 Role).\n\nTo switch to the $roleTitle portal, you need to log out of your current account and sign in with your $roleTitle credentials.',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC107)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Logging out ends your current session securely.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(confirmCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Log Out & Switch', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (shouldLogOut == true && mounted) {
      await SupabaseService.signOut();
      if (mounted) {
        UserRole roleEnum = UserRole.provider;
        if (targetRole == 'receiver') {
          roleEnum = UserRole.receiver;
        } else if (targetRole == 'volunteer') {
          roleEnum = UserRole.volunteer;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginPage(initialRole: roleEnum),
          ),
          (route) => false,
        );
      }
    }
  }

  void _showRoleSwitchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFFFFC107), size: 24),
            SizedBox(width: 8),
            Text(
              'Switch Portal / Role',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmLogOutToSwitch('provider');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Food Provider', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            if (_currentRole == 'provider') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Restaurants, Hotels, Cloud Kitchens & Caterers', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmLogOutToSwitch('receiver');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Receiver (NGO & Shelters)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            if (_currentRole == 'receiver') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Relief Centers, Shelters & Beneficiaries', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmLogOutToSwitch('volunteer');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.electric_moped_rounded, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Volunteer Rescue Squad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            if (_currentRole == 'volunteer') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Dispatch, Transit & Handover Verification Couriers', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  AppDrawer.confirmAndSignOut(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out to Switch Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeContent;
    if (_currentRole == 'provider') {
      activeContent = ProviderDashboard(onSwitchRole: _showRoleSwitchDialog);
    } else if (_currentRole == 'receiver') {
      activeContent = ReceiverDashboard(onSwitchRole: _showRoleSwitchDialog);
    } else if (_currentRole == 'volunteer') {
      activeContent = VolunteerDashboard(onSwitchRole: _showRoleSwitchDialog);
    } else {
      activeContent = _buildFallbackDashboard(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        if (isMobile) {
          return activeContent;
        }
        return activeContent;
      },
    );
  }

  Widget _buildFallbackDashboard(BuildContext context) {
    final user = SupabaseService.currentUser;
    final meta = user?.userMetadata ?? {};
    final fullName = meta['full_name'] ?? meta['name'] ?? user?.email?.split('@').first ?? 'Food Flow Partner';
    final email = user?.email ?? 'member@foodflow.org';

    String roleDisplayTitle = 'Food Provider';
    Color roleBadgeColor = const Color(0xFFF59E0B);
    Color roleBgColor = const Color(0xFFFEF3C7);
    IconData roleIcon = Icons.restaurant_rounded;

    if (_currentRole == 'receiver') {
      roleDisplayTitle = 'NGO / Food Receiver';
      roleBadgeColor = const Color(0xFF10B981);
      roleBgColor = const Color(0xFFDCFCE7);
      roleIcon = Icons.volunteer_activism_rounded;
    } else if (_currentRole == 'volunteer') {
      roleDisplayTitle = 'Volunteer Courier';
      roleBadgeColor = const Color(0xFF2563EB);
      roleBgColor = const Color(0xFFEFF6FF);
      roleIcon = Icons.two_wheeler_rounded;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF7),
      drawer: AppDrawer(
        activeRole: roleDisplayTitle,
        onSwitchRole: _showRoleSwitchDialog,
        onProfileUpdated: () {
          setState(() {});
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            const FoodFlowIcon(size: 32),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Food Flow',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'ZERO-WASTE NETWORK',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _showRoleSwitchDialog,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFD97706)),
            label: const Text(
              'Switch Role',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(width: 6),
          AppDrawer.buildSignOutButton(context),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Greeting & Role Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: roleBgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(roleIcon, color: roleBadgeColor, size: 30),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Welcome, $fullName',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: roleBgColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    roleDisplayTitle.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: roleBadgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Signed in as $email · Onboarding complete',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Location: ${LocationService.currentProviderLocation?.shortLocation ?? LocationService.currentProviderLocation?.formattedAddress ?? meta['operating_location'] ?? 'Bengaluru, India'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Clean Canvas Placeholder
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.palette_outlined, color: Color(0xFFD97706), size: 32),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Clean Canvas Ready',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All previous wireframe dashboards have been cleared. Tell me what layout, cards, or flows you would like to start building first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Clean Footer
                const Center(
                  child: Text(
                    '© 2026 Food Flow — Zero Waste Logistics System',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
