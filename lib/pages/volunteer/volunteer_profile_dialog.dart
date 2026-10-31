import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';
import 'volunteer_availability_dialog.dart';

class VolunteerProfileDialog extends StatefulWidget {
  final String volunteerName;
  final String operatingCity;
  final bool isAvailable;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback? onProfileUpdated;

  const VolunteerProfileDialog({
    super.key,
    required this.volunteerName,
    required this.operatingCity,
    required this.isAvailable,
    required this.onAvailabilityChanged,
    this.onProfileUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String volunteerName,
    required String operatingCity,
    required bool isAvailable,
    required ValueChanged<bool> onAvailabilityChanged,
    VoidCallback? onProfileUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VolunteerProfileDialog(
        volunteerName: volunteerName,
        operatingCity: operatingCity,
        isAvailable: isAvailable,
        onAvailabilityChanged: onAvailabilityChanged,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<VolunteerProfileDialog> createState() => _VolunteerProfileDialogState();
}

class _VolunteerProfileDialogState extends State<VolunteerProfileDialog> {
  late String _name;
  late String _phone;
  late String _location;
  late String _email;
  late bool _available;

  @override
  void initState() {
    super.initState();
    _name = widget.volunteerName;
    _location = widget.operatingCity;
    _available = widget.isAvailable;
    _email = SupabaseService.currentUser?.email ?? 'volunteer.squad@foodflow.org';

    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final fullName = meta['full_name'] as String? ?? meta['name'] as String?;
    final phone = meta['phone'] as String?;
    final loc = meta['operating_location'] as String?;

    if (fullName != null && fullName.trim().isNotEmpty && fullName != 'FoodFlow Partner') {
      _name = fullName.trim();
    }
    _phone = phone ?? '';
    if (loc != null && loc.trim().isNotEmpty) {
      _location = loc.trim();
    }
  }

  Future<void> _openEditProfileDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: _name);
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
                                'Edit Volunteer Profile',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update courier identity & operating area',
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

                    // Full Name / Courier Identity
                    const Text(
                      'Full Name / Courier Identity *',
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
                        hintText: 'e.g. Arjun Sharma or Yashraj',
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
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone / WhatsApp
                    const Text(
                      'Contact Phone / WhatsApp *',
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
                        hintText: '+91 95556 51225',
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

                    // Operating Area / City with [ 📍 Detect GPS ]
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Operating Area / City',
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
                        hintText: 'e.g. Greater Noida Hub or Koramangala, Bengaluru',
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
                                          organizationName: 'Volunteer Rescue Squad',
                                          phone: phoneCtrl.text.trim(),
                                          location: locCtrl.text.trim(),
                                          latitude: detectedLat,
                                          longitude: detectedLng,
                                        );

                                        if (mounted) {
                                          setState(() {
                                            _name = nameCtrl.text.trim();
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
                                                  Text('Volunteer profile updated successfully!'),
                                                ],
                                              ),
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() => isSaving = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      contentPadding: const EdgeInsets.all(24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Close row
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Avatar with Edit Badge
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openEditProfileDialog(context),
                borderRadius: BorderRadius.circular(36),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFC107), width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'V',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                        ),
                      ),
                    ),
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
            const SizedBox(height: 12),

            // Name & Role & Location
            Text(
              _name.isNotEmpty ? _name : 'Yash',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Volunteer Squad',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _location.isNotEmpty ? _location : 'Greater Noida',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _email,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),

            // Statistics Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('42', 'Tasks Completed'),
                  Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                  _buildStatItem('1,240', 'Meals Delivered'),
                  Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                  _buildStatItem('98%', 'Success Rate'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Interactive Edit Profile tile
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFFD97706)),
              ),
              title: const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
              subtitle: const Text(
                'Update courier identity & operating area',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              onTap: () => _openEditProfileDialog(context),
            ),

            // Availability option
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF64748B)),
              ),
              title: const Text(
                'Availability',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
              subtitle: Text(
                _available ? '🟢 Available for Tasks' : '⚪ Offline',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.pop(context);
                VolunteerAvailabilityDialog.show(
                  context,
                  isAvailable: _available,
                  onAvailabilityChanged: (val) {
                    setState(() => _available = val);
                    widget.onAvailabilityChanged(val);
                  },
                );
              },
            ),

            if (_phone.isNotEmpty)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF64748B)),
                ),
                title: const Text(
                  'Contact Phone',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
                ),
                subtitle: Text(
                  _phone,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),

            // Sign out button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  AppDrawer.confirmAndSignOut(context);
                },
                icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Log Out of Account',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
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
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
