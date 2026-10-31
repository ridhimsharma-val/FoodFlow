import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'brand_logo.dart';

class AppDrawer extends StatefulWidget {
  final String activeRole;
  final VoidCallback? onSwitchRole;
  final VoidCallback? onProfileUpdated;

  const AppDrawer({
    super.key,
    required this.activeRole,
    this.onSwitchRole,
    this.onProfileUpdated,
  });

  static Future<void> confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Confirm Sign Out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out from Food Flow? You can sign back in anytime.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
        Navigator.pop(context); // close drawer if open
      }
      await SupabaseService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  static Widget buildSignOutButton(BuildContext context, {bool compact = false}) {
    if (compact) {
      return IconButton(
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
        tooltip: 'Sign Out / Logout',
        onPressed: () => confirmAndSignOut(context),
      );
    }
    return TextButton.icon(
      onPressed: () => confirmAndSignOut(context),
      icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
      label: const Text(
        'Sign Out',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEF4444),
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: const Color(0xFFFEF2F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFFCA5A5), width: 0.8),
        ),
      ),
    );
  }

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late String _displayName;
  late String _orgName;
  late String _phone;
  late String _location;
  late String _email;
  late String _avatarUrl;

  @override
  void initState() {
    super.initState();
    _initUserData();
    _fetchFullProfile();
  }

  void _initUserData() {
    final user = SupabaseService.currentUser;
    final meta = user?.userMetadata ?? {};
    _displayName = meta['full_name'] ?? meta['name'] ?? user?.email?.split('@').first ?? 'Food Flow Member';
    _orgName = meta['organization_name'] ?? 'Food Flow Community Partner';
    _phone = meta['phone'] ?? user?.phone ?? '';
    _location = meta['operating_location'] ?? LocationService.currentProviderLocation?.formattedAddress ?? 'Bengaluru, India';
    _email = user?.email ?? 'member@foodflow.org';
    _avatarUrl = (meta['avatar_url'] ?? meta['picture'] ?? '') as String;
  }

  Future<void> _fetchFullProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null || !SupabaseService.isInitialized) return;
    try {
      final profile = await SupabaseService.getProfile(user.id);
      if (profile != null && mounted) {
        setState(() {
          if (profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
            _displayName = profile['full_name'].toString();
          }
        });
      }

      // Role specific table lookups
      final roleLower = widget.activeRole.toLowerCase();
      if (roleLower.contains('provider')) {
        final prov = await SupabaseService.client
            .from('providers')
            .select('organization_name, contact_person, contact_phone, address')
            .eq('user_id', user.id)
            .maybeSingle();
        if (prov != null && mounted) {
          setState(() {
            if (prov['organization_name'] != null && prov['organization_name'].toString().isNotEmpty) {
              _orgName = prov['organization_name'].toString();
            }
            if (prov['contact_person'] != null && prov['contact_person'].toString().isNotEmpty) {
              _displayName = prov['contact_person'].toString();
            }
            if (prov['contact_phone'] != null) _phone = prov['contact_phone'].toString();
            if (prov['address'] != null) _location = prov['address'].toString();
          });
        }
      } else if (roleLower.contains('receiver')) {
        final rec = await SupabaseService.client
            .from('receivers')
            .select('organization_name, contact_person, contact_phone, address')
            .eq('user_id', user.id)
            .maybeSingle();
        if (rec != null && mounted) {
          setState(() {
            if (rec['organization_name'] != null && rec['organization_name'].toString().isNotEmpty) {
              _orgName = rec['organization_name'].toString();
            }
            if (rec['contact_person'] != null && rec['contact_person'].toString().isNotEmpty) {
              _displayName = rec['contact_person'].toString();
            }
            if (rec['contact_phone'] != null) _phone = rec['contact_phone'].toString();
            if (rec['address'] != null) _location = rec['address'].toString();
          });
        }
      } else if (roleLower.contains('volunteer')) {
        final vol = await SupabaseService.client
            .from('volunteers')
            .select('full_name, phone, operating_location')
            .eq('user_id', user.id)
            .maybeSingle();
        if (vol != null && mounted) {
          setState(() {
            if (vol['full_name'] != null && vol['full_name'].toString().isNotEmpty) {
              _displayName = vol['full_name'].toString();
            }
            if (vol['phone'] != null) _phone = vol['phone'].toString();
            if (vol['operating_location'] != null) _location = vol['operating_location'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint('AppDrawer profile lookup notice: $e');
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: _displayName);
    final orgCtrl = TextEditingController(text: _orgName);
    final phoneCtrl = TextEditingController(text: _phone);
    final locCtrl = TextEditingController(text: _location);
    bool isSaving = false;
    bool isDetecting = false;
    double? detectedLat;
    double? detectedLng;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Icon & Title
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: Color(0xFFD97706),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Profile & Organization',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update public identity & details',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 16),

                    // Active Role & Email Info Chips
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.activeRole.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 18),

                    // Organization Name
                    const Text(
                      'Organization / Entity Name *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: orgCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Grand Palace Banquet & Kitchen',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.business_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Organization name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Display Name / Representative Name
                    const Text(
                      'Display Name / Authorized Representative *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Rajesh Sharma or yashrajdevmail',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Display name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Phone
                    const Text(
                      'Contact Phone / WhatsApp',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '+91 98765 43210',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Operating Location with [ 📍 Detect Location ]
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Operating Location / Address',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: isDetecting
                              ? null
                              : () async {
                                  setDialogState(() => isDetecting = true);
                                  try {
                                    final res = await LocationService.detectCurrentLocation();
                                    if (res != null) {
                                      detectedLat = res.latitude;
                                      detectedLng = res.longitude;
                                      locCtrl.text = res.shortLocation ?? res.formattedAddress;
                                    }
                                  } catch (e) {
                                    debugPrint('Detect location error: $e');
                                  } finally {
                                    setDialogState(() => isDetecting = false);
                                  }
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFBBF24)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDetecting)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFB45309)),
                                  )
                                else
                                  const Icon(Icons.my_location_rounded, size: 12, color: Color(0xFFB45309)),
                                const SizedBox(width: 4),
                                const Text(
                                  'Detect GPS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: locCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Connaught Place, New Delhi or Indiranagar, Bengaluru',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setDialogState(() => isSaving = true);
                                      try {
                                        await SupabaseService.updateUserProfile(
                                          fullName: nameCtrl.text.trim(),
                                          organizationName: orgCtrl.text.trim(),
                                          phone: phoneCtrl.text.trim(),
                                          location: locCtrl.text.trim(),
                                          latitude: detectedLat,
                                          longitude: detectedLng,
                                        );

                                        if (mounted) {
                                          setState(() {
                                            _displayName = nameCtrl.text.trim();
                                            _orgName = orgCtrl.text.trim();
                                            _phone = phoneCtrl.text.trim();
                                            _location = locCtrl.text.trim();
                                          });
                                        }

                                        widget.onProfileUpdated?.call();

                                        if (dialogCtx.mounted) {
                                          Navigator.pop(dialogCtx);
                                        }

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: const Color(0xFF16A34A),
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Updated ${orgCtrl.text.trim()} profile successfully!',
                                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                                  ),
                                                ],
                                              ),
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() => isSaving = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.redAccent,
                                              content: Text('Failed to update: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                    )
                                  : const Icon(Icons.check_rounded, size: 18, color: Colors.black87),
                              label: Text(
                                isSaving ? 'Saving...' : 'Save Changes',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF5BA13),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer User Header Card with Interactive Avatar & Edit trigger
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFFCFBF7),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Clickable Circle Avatar with Edit Badge
                  Tooltip(
                    message: 'Click to edit profile & organization',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showEditProfileDialog(context),
                        borderRadius: BorderRadius.circular(26),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (_avatarUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Image.network(
                                  _avatarUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildAvatarFallback(_displayName),
                                ),
                              )
                            else
                              _buildAvatarFallback(_displayName),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.edit, size: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // User Information with tap to edit
                  Expanded(
                    child: InkWell(
                      onTap: () => _showEditProfileDialog(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_orgName.isNotEmpty && _orgName != _displayName) ...[
                              const SizedBox(height: 1),
                              Text(
                                _orgName,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD97706),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              _email,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.activeRole.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF64748B)),
                    tooltip: 'Edit Profile',
                    onPressed: () => _showEditProfileDialog(context),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: Color(0xFFD97706)),
                    title: const Text('Edit Profile & Organization',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Display name, organization, contact info & location',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  if (widget.onSwitchRole != null)
                    SizedBox(
                      height: 1,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(200, 1),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSwitchRole!();
                        },
                        child: const Text(
                          'Switch Role',
                          style: TextStyle(color: Colors.transparent, fontSize: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Red Logout Button at Bottom
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => AppDrawer.confirmAndSignOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Sign Out / Logout',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return const CircleAvatar(
      radius: 26,
      backgroundColor: Color(0xFFFEF9E6),
      child: FoodFlowIcon(size: 52),
    );
  }
}
