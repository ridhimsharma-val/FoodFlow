import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class ReceiverProfileDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final email = user?.email ?? 'ngo.shelter@foodflow.org';

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

            // Profile Avatar & Information
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFFEF3C7),
              child: Text(
                receiverName.isNotEmpty ? receiverName[0].toUpperCase() : 'R',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              receiverName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 2),
            Text(
              organizationName,
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
              email,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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

            // Profile Options
            _buildProfileOption(
              context,
              icon: Icons.edit_note_rounded,
              title: 'Edit Profile',
              subtitle: 'Update representative name & details',
            ),
            _buildProfileOption(
              context,
              icon: Icons.domain_rounded,
              title: 'My Organization',
              subtitle: 'Shelter intake address & capacity settings',
            ),
            _buildProfileOption(
              context,
              icon: Icons.contact_phone_outlined,
              title: 'Contact Information',
              subtitle: 'Phone number and notification preference',
            ),
            _buildProfileOption(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Security, notifications & preferences',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
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
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            content: Text('$title settings loaded.'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
