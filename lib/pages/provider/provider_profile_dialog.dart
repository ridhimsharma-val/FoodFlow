import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';

class ProviderProfileDialog extends StatefulWidget {
  final String providerName;
  final String category;
  final String location;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onSwitchRole;

  const ProviderProfileDialog({
    super.key,
    required this.providerName,
    required this.category,
    required this.location,
    this.onProfileUpdated,
    this.onSwitchRole,
  });

  static Future<void> show(
    BuildContext context, {
    required String providerName,
    required String category,
    required String location,
    VoidCallback? onProfileUpdated,
    VoidCallback? onSwitchRole,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProviderProfileDialog(
        providerName: providerName,
        category: category,
        location: location,
        onProfileUpdated: onProfileUpdated,
        onSwitchRole: onSwitchRole,
      ),
    );
  }

  @override
  State<ProviderProfileDialog> createState() => _ProviderProfileDialogState();
}

class _ProviderProfileDialogState extends State<ProviderProfileDialog> {
  late String _providerOrgName;
  late String _repName;
  late String _phone;
  late String _location;
  late String _email;
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _location = widget.location;
    _providerOrgName = widget.providerName;
    _email = SupabaseService.currentUser?.email ?? 'kitchen.partner@foodflow.org';

    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final org = meta['organization_name'] as String?;
    final rep = meta['authorized_representative'] as String? ??
        meta['contact_person'] as String? ??
        meta['full_name'] as String? ??
        meta['name'] as String?;
    final phone = meta['phone'] as String?;
    final loc = meta['operating_location'] as String?;

    if (org != null && org.trim().isNotEmpty && org != 'FoodFlow Partner') {
      _providerOrgName = org.trim();
    }
    _repName = (rep != null && rep.trim().isNotEmpty) ? rep.trim() : _providerOrgName;
    _phone = phone ?? '';
    if (loc != null && loc.trim().isNotEmpty) {
      _location = loc.trim();
    }
  }

  Future<void> _openEditProfileDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final orgCtrl = TextEditingController(text: _providerOrgName);
    final repCtrl = TextEditingController(text: _repName);
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
                    // Header
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

                    // Organization / Kitchen Name
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
                          return 'Please enter your organization or business name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Authorized Representative / Display Name
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
                      controller: repCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Rajesh Kumar',
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
                          return 'Please enter representative name';
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
                        hintText: 'e.g. +91 98765 43210',
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

                    // Operating Location with [ 📍 Detect GPS ]
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
                                          fullName: repCtrl.text.trim(),
                                          organizationName: orgCtrl.text.trim(),
                                          phone: phoneCtrl.text.trim(),
                                          location: locCtrl.text.trim(),
                                          latitude: detectedLat,
                                          longitude: detectedLng,
                                        );

                                        if (mounted) {
                                          setState(() {
                                            _providerOrgName = orgCtrl.text.trim();
                                            _repName = repCtrl.text.trim();
                                            _phone = phoneCtrl.text.trim();
                                            _location = locCtrl.text.trim();
                                          });
                                          widget.onProfileUpdated?.call();
                                        }

                                        if (dialogCtx.mounted) {
                                          Navigator.pop(dialogCtx);
                                        }

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: const Color(0xFF10B981),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Profile updated successfully!'),
                                                ],
                                              ),
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } catch (err) {
                                        debugPrint('Save profile error: $err');
                                        if (dialogCtx.mounted) {
                                          setDialogState(() => isSaving = false);
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
                                backgroundColor: const Color(0xFFFFC107),
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
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(22),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Title & Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Provider Profile',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profile Avatar & Information
              InkWell(
                onTap: () => _openEditProfileDialog(context),
                borderRadius: BorderRadius.circular(36),
                child: Tooltip(
                  message: 'Click to edit profile',
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFFEF3C7),
                        child: Text(
                          _providerOrgName.isNotEmpty ? _providerOrgName[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Business Name
              Text(
                _providerOrgName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),

              // Authorized Representative Name
              Text(
                _repName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Badge Pill: PROVIDER / KITCHEN
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'PROVIDER / KITCHEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                _email,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),

              // Location
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _location.isNotEmpty ? _location : 'Indiranagar, Bengaluru',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Statistics Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '1,240',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Meals Donated',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 28,
                      child: VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
                    ),
                    Column(
                      children: [
                        Text(
                          '98%',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Successful Pickups',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Options List
              _buildProfileOption(
                context,
                icon: Icons.edit_note_rounded,
                title: 'Edit Profile',
                subtitle: 'Update business name, contact person & location',
                onTap: () => _openEditProfileDialog(context),
              ),
              _buildProfileOption(
                context,
                icon: Icons.domain_rounded,
                title: 'My Organization',
                subtitle: 'Category: $_category • Commercial Kitchen License',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      content: Text('Organization: $_providerOrgName ($_category) - Verified FSSAI Kitchen'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _buildProfileOption(
                context,
                icon: Icons.contact_phone_outlined,
                title: 'Contact Information',
                subtitle: _phone.isNotEmpty ? _phone : _email,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      content: Text('Contact: ${_phone.isNotEmpty ? _phone : "No phone saved"} | $_email'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _buildProfileOption(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings & Security',
                subtitle: 'Security, notifications & preferences',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      content: const Text('Account security & notification preferences are up to date.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (widget.onSwitchRole != null)
                _buildProfileOption(
                  context,
                  icon: Icons.swap_horiz_rounded,
                  title: 'Switch Role / Portal',
                  subtitle: 'Switch to Receiver (NGO) or Volunteer Squad',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSwitchRole!();
                  },
                ),

              const SizedBox(height: 16),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    AppDrawer.confirmAndSignOut(context);
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Log Out of Account',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFFD97706)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}
