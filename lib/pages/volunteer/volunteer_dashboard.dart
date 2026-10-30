import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';
import 'volunteer_home_tab.dart';
import 'volunteer_tasks_page.dart';
import 'volunteer_history_page.dart';
import 'volunteer_payments_page.dart';
import 'volunteer_impact_page.dart';
import 'volunteer_notifications_dialog.dart';
import 'volunteer_profile_dialog.dart';

class VolunteerDashboard extends StatefulWidget {
  final VoidCallback? onSwitchRole;

  const VolunteerDashboard({super.key, this.onSwitchRole});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  int _selectedTabIndex = 0;
  LatLng _volunteerLocation = const LatLng(12.9352, 77.6245); // Koramangala Hub default
  String _selectedLocation = 'Greater Noida Hub';
  bool _isAvailable = true;
  bool _syncInitialized = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _currentVolunteerName {
    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final full = meta['full_name'] as String? ?? meta['name'] as String?;
    if (full != null && full.trim().isNotEmpty && full != 'FoodFlow Partner') {
      return full.trim();
    }
    final email = SupabaseService.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Yash';
  }

  @override
  void initState() {
    super.initState();
    _initVolunteerLocation();
    _loadSavedVolunteerProfile();
    if (_selectedLocation.isEmpty || !LocationService.hasRealLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_selectedLocation.isEmpty || !LocationService.hasRealLocation)) {
          _autoDetectRealLocation();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initVolunteerLocation();
    if (!_syncInitialized) {
      _syncInitialized = true;
      FoodRescueService.instance.initSupabaseSync('volunteer');
    }
  }

  void _initVolunteerLocation() {
    final sessionLoc = LocationService.currentProviderLocation;
    if (sessionLoc != null) {
      _selectedLocation = (sessionLoc.shortLocation != null && sessionLoc.shortLocation!.isNotEmpty)
          ? '${sessionLoc.shortLocation} Hub'
          : sessionLoc.formattedAddress;
      _volunteerLocation = sessionLoc.latLng;
    } else {
      final user = SupabaseService.currentUser;
      final meta = user?.userMetadata ?? {};
      final savedLoc = meta['operating_location'] as String?;
      final lat = meta['latitude'];
      final lng = meta['longitude'];
      if (savedLoc != null && savedLoc.isNotEmpty) {
        _selectedLocation = savedLoc;
      }
      if (lat != null && lng != null) {
        final parsedLat = double.tryParse(lat.toString());
        final parsedLng = double.tryParse(lng.toString());
        if (parsedLat != null && parsedLng != null) {
          _volunteerLocation = LatLng(parsedLat, parsedLng);
        }
      }
    }
  }

  Future<void> _loadSavedVolunteerProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null || !SupabaseService.isInitialized) return;
    try {
      final row = await SupabaseService.client
          .from('volunteers')
          .select('operating_location, is_active')
          .or('id.eq.${user.id},user_id.eq.${user.id}')
          .maybeSingle();

      if (row != null && mounted) {
        final loc = row['operating_location'] as String?;
        final active = row['is_active'] as bool?;
        setState(() {
          if (loc != null && loc.trim().isNotEmpty) {
            _selectedLocation = loc.trim();
          }
          if (active != null) {
            _isAvailable = active;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _autoDetectRealLocation() async {
    try {
      final res = await LocationService.detectCurrentLocation();
      if (res != null && mounted) {
        setState(() {
          _selectedLocation = (res.shortLocation != null && res.shortLocation!.isNotEmpty)
              ? '${res.shortLocation} Hub'
              : res.formattedAddress;
          _volunteerLocation = res.latLng;
        });
        LocationService.setProviderLocation(res);
      }
    } catch (_) {}
  }

  void _openNotifications() {
    VolunteerNotificationsDialog.show(context);
  }

  void _openProfile() {
    VolunteerProfileDialog.show(
      context,
      volunteerName: _currentVolunteerName,
      operatingCity: _selectedLocation,
      isAvailable: _isAvailable,
      onAvailabilityChanged: (val) => setState(() => _isAvailable = val),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: AppDrawer(
        activeRole: 'Volunteer Courier',
        onSwitchRole: widget.onSwitchRole,
        onProfileUpdated: () => setState(() {}),
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Tab 0: Volunteer Home
          VolunteerHomeTab(
            volunteerName: _currentVolunteerName,
            location: _selectedLocation,
            latLng: _volunteerLocation,
            isAvailable: _isAvailable,
            onAvailabilityChanged: (val) => setState(() => _isAvailable = val),
            onOpenTasksTab: () => setState(() => _selectedTabIndex = 1),
            onOpenHistoryTab: () => setState(() => _selectedTabIndex = 2),
            onOpenPaymentsTab: () => setState(() => _selectedTabIndex = 3),
            onOpenNotifications: _openNotifications,
            onOpenProfile: _openProfile,
            onDetectLocation: _autoDetectRealLocation,
            onSwitchRole: widget.onSwitchRole,
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),

          // Tab 1: Available Tasks Discovery
          VolunteerTasksPage(
            volunteerLocation: _volunteerLocation,
            volunteerLocationName: _selectedLocation,
            isAvailable: _isAvailable,
            onAvailabilityChanged: (val) => setState(() => _isAvailable = val),
          ),

          // Tab 2: My Tasks & History
          VolunteerHistoryPage(
            onOpenTasks: () => setState(() => _selectedTabIndex = 1),
          ),

          // Tab 3: Payments & Confirmation
          VolunteerPaymentsPage(
            onOpenTasks: () => setState(() => _selectedTabIndex = 1),
          ),

          // Tab 4: Volunteer Impact
          const VolunteerImpactPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: const Color(0xFFFEF3C7),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFFD97706)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.delivery_dining_rounded, color: Color(0xFFD97706)),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.history_rounded, color: Color(0xFFD97706)),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706)),
              label: 'Payments',
            ),
            NavigationDestination(
              icon: Icon(Icons.eco_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.eco_rounded, color: Color(0xFFD97706)),
              label: 'Impact',
            ),
          ],
        ),
      ),
    );
  }
}
