import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/active_rescue_bottom_popup.dart';
import 'receiver_home_tab.dart';
import 'browse_food_page.dart';
import 'my_claims_page.dart';
import 'receiver_impact_page.dart';
import 'receiver_notifications_dialog.dart';
import 'receiver_profile_dialog.dart';

class ReceiverDashboard extends StatefulWidget {
  final VoidCallback? onSwitchRole;

  const ReceiverDashboard({super.key, this.onSwitchRole});

  @override
  State<ReceiverDashboard> createState() => _ReceiverDashboardState();
}

class _ReceiverDashboardState extends State<ReceiverDashboard> {
  int _selectedTabIndex = 0;
  LatLng _receiverLocation = const LatLng(12.9860, 77.6350);
  String _selectedLocation = '';
  String? _savedOrgName;
  bool _syncInitialized = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _currentReceiverName {
    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final full = meta['full_name'] as String?;
    if (full != null && full.trim().isNotEmpty && full != 'FoodFlow Partner') {
      return full.trim();
    }
    final email = SupabaseService.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Asha Verma';
  }

  String get _currentOrgName {
    if (_savedOrgName != null && _savedOrgName!.trim().isNotEmpty && _savedOrgName != 'FoodFlow Partner') {
      return _savedOrgName!.trim();
    }
    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final org = meta['organization_name'] as String?;
    if (org != null && org.trim().isNotEmpty && org != 'FoodFlow Partner') {
      return org.trim();
    }
    return 'Helping Hands NGO';
  }

  @override
  void initState() {
    super.initState();
    _initReceiverLocation();
    _loadSavedReceiverLocation();
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
    _initReceiverLocation();
    _loadSavedReceiverLocation();
    if (!_syncInitialized) {
      _syncInitialized = true;
      FoodRescueService.instance.initSupabaseSync('receiver');
    }
  }

  void _initReceiverLocation() {
    final sessionLoc = LocationService.currentProviderLocation;
    if (sessionLoc != null) {
      _selectedLocation = sessionLoc.displayAddress;
      _receiverLocation = sessionLoc.latLng;
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
          _receiverLocation = LatLng(parsedLat, parsedLng);
        }
      }
    }
  }

  Future<void> _loadSavedReceiverLocation() async {
    final user = SupabaseService.currentUser;
    if (user == null || !SupabaseService.isInitialized) return;
    try {
      var row = await SupabaseService.client
          .from('receivers')
          .select('operating_location, organization_name')
          .or('id.eq.${user.id},user_id.eq.${user.id}')
          .maybeSingle();

      if (row == null || (row['organization_name'] == null && row['operating_location'] == null)) {
        final prof = await SupabaseService.client
            .from('profiles')
            .select('operating_location, organization_name')
            .eq('id', user.id)
            .maybeSingle();
        if (prof != null) row = prof;
      }

      if (row != null && mounted) {
        final loc = row['operating_location'] as String?;
        final org = row['organization_name'] as String?;
        setState(() {
          if (org != null && org.trim().isNotEmpty && org.trim() != 'FoodFlow Partner') {
            _savedOrgName = org.trim();
          }
          if (loc != null && loc.trim().isNotEmpty && (!LocationService.hasRealLocation || _selectedLocation.isEmpty)) {
            _selectedLocation = loc.trim();
          }
        });
        if (loc != null && loc.trim().isNotEmpty) {
          LocationService.setProviderLocationCoords(
            locationName: loc.trim(),
            latitude: _receiverLocation.latitude,
            longitude: _receiverLocation.longitude,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _autoDetectRealLocation() async {
    try {
      final res = await LocationService.detectCurrentLocation();
      if (res != null && mounted) {
        setState(() {
          _selectedLocation = res.displayAddress;
          _receiverLocation = res.latLng;
        });
        LocationService.setProviderLocation(res);
        if (SupabaseService.isAuthenticated) {
          SupabaseService.updateUserLocation(
            locationName: _selectedLocation,
            latitude: res.latitude,
            longitude: res.longitude,
          );
        }
      }
    } catch (_) {}
  }

  void _openNotifications() {
    ReceiverNotificationsDialog.show(context);
  }

  void _openProfile() {
    ReceiverProfileDialog.show(
      context,
      receiverName: _currentReceiverName,
      organizationName: _currentOrgName,
      location: _selectedLocation,
      onProfileUpdated: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: AppDrawer(
        activeRole: 'NGO / Food Receiver',
        onSwitchRole: widget.onSwitchRole,
        onProfileUpdated: () => setState(() {}),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTabIndex,
            children: [
              // Tab 0: Receiver Home Dashboard
              ReceiverHomeTab(
                receiverName: _currentReceiverName,
                organizationName: _currentOrgName,
                location: _selectedLocation,
                latLng: _receiverLocation,
                onOpenBrowseTab: () => setState(() => _selectedTabIndex = 1),
                onOpenMyClaimsTab: () => setState(() => _selectedTabIndex = 2),
                onOpenNotifications: _openNotifications,
                onOpenProfile: _openProfile,
                onDetectLocation: _autoDetectRealLocation,
                onSwitchRole: widget.onSwitchRole,
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              ),

              // Tab 1: Browse Available Food
              BrowseFoodPage(
                receiverLocation: _receiverLocation,
                receiverLocationName: _selectedLocation,
              ),

              // Tab 2: My Claims
              MyClaimsPage(
                onOpenBrowse: () => setState(() => _selectedTabIndex = 1),
              ),

              // Tab 3: Receiver Impact
              const ReceiverImpactPage(),
            ],
          ),

          // Active Rescue Bottom Popup (communicates via Supabase Realtime across Provider, Receiver, and Volunteer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActiveRescueBottomPopup(
              role: ActiveRescueRole.receiver,
              receiverOrg: _currentOrgName,
            ),
          ),
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
              icon: Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.search_rounded, color: Color(0xFFD97706)),
              label: 'Browse',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706)),
              label: 'My Claims',
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
