import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';

class ReceiverProfileDialog extends StatefulWidget {
  final String receiverName;
  final String organizationName;
  final String location;
  final VoidCallback? onProfileUpdated;

  const ReceiverProfileDialog({
    super.key,
    required this.receiverName,
    required this.organizationName,
    required this.location,
    this.onProfileUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String receiverName,
    required String organizationName,
    required String location,
    VoidCallback? onProfileUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiverProfileDialog(
        receiverName: receiverName,
        organizationName: organizationName,
        location: location,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<ReceiverProfileDialog> createState() => _ReceiverProfileDialogState();
}

class _ReceiverProfileDialogState extends State<ReceiverProfileDialog> {
  late String _orgName;
  late String _repName;
  late String _phone;
  late String _location;
  late String _email;

  @override
  void initState() {
    super.initState();
    _orgName = widget.organizationName;
    _repName = widget.receiverName;
    _location = widget.location;
    _email = SupabaseService.currentUser?.email ?? 'ngo.shelter@foodflow.org';

    final meta = SupabaseService.currentUser?.userMetadata ?? {};
    final org = meta['organization_name'] as String?;
    final rep = meta['authorized_representative'] as String? ??
        meta['contact_person'] as String? ??
        meta['full_name'] as String? ??
        meta['name'] as String?;
    final phone = meta['phone'] as String?;
    final loc = meta['operating_location'] as String?;

    if (org != null && org.trim().isNotEmpty && org != 'FoodFlow Partner') {
      _orgName = org.trim();
    }
    if (rep != null && rep.trim().isNotEmpty && rep != 'FoodFlow Partner') {
      _repName = rep.trim();
    }
    _phone = phone ?? '';
    if (loc != null && loc.trim().isNotEmpty) {
      _location = loc.trim();
    }
  }

  Future<void> _openEditProfileDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final orgCtrl = TextEditingController(text: _orgName);
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
                                'Edit Shelter & Receiver Profile',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update NGO identity & intake details',
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

                    // Organization / Shelter Name
                    const Text(
                      'Organization / Shelter Name *',
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
                        hintText: 'e.g. Helping Hands Shelter & Foundation',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.domain_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                          return 'Please enter your shelter or organization name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Authorized Representative / Contact Person
                    const Text(
                      'Authorized Representative / Contact Name *',
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
                        hintText: 'e.g. Priya Sharma or Asha Verma',
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
                          return 'Please enter the representative name';
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

                    // Operating Location / Shelter Address with [ 📍 Detect GPS ]
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Operating Location / Shelter Address',
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
                        hintText: 'e.g. Greater Noida, Delhi NCR or Indiranagar, Bengaluru',
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
                                            _orgName = orgCtrl.text.trim();
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
                                                  Text('Receiver profile updated successfully!'),
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
      contentPadding: const EdgeInsets.all(22),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Receiver Profile',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
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

            // Profile Avatar & Information (Interactive Avatar with Edit Badge)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openEditProfileDialog(context),
                borderRadius: BorderRadius.circular(40),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFFEF3C7),
                      child: Text(
                        _repName.isNotEmpty ? _repName[0].toUpperCase() : 'R',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
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
            const SizedBox(height: 10),
            Text(
              _repName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 2),
            Text(
              _orgName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'RECEIVER / NGO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _email,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_location.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _location,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
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
                        '120',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Meals Claimed',
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
                        '96%',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
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

            // Profile Options - Interactive Edit Profile tile
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
                'Update representative name & shelter details',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              onTap: () => _openEditProfileDialog(context),
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

            // Sign out button matching Provider
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
}
