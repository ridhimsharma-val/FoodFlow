import 'package:flutter/material.dart';
import 'volunteer_availability_dialog.dart';

class VolunteerProfileDialog extends StatelessWidget {
  final String volunteerName;
  final String operatingCity;
  final bool isAvailable;
  final ValueChanged<bool> onAvailabilityChanged;

  const VolunteerProfileDialog({
    super.key,
    required this.volunteerName,
    required this.operatingCity,
    required this.isAvailable,
    required this.onAvailabilityChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String volunteerName,
    required String operatingCity,
    required bool isAvailable,
    required ValueChanged<bool> onAvailabilityChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VolunteerProfileDialog(
        volunteerName: volunteerName,
        operatingCity: operatingCity,
        isAvailable: isAvailable,
        onAvailabilityChanged: onAvailabilityChanged,
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

            // Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFC107), width: 2.5),
              ),
              child: const Center(
                child: Icon(Icons.person_rounded, size: 38, color: Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 12),

            // Name & Role & Location
            Text(
              volunteerName.isNotEmpty ? volunteerName : 'Yash',
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
                    'Volunteer',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  operatingCity.isNotEmpty ? operatingCity : 'Greater Noida',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 20),

            // Options List
            _buildOptionTile(
              context,
              icon: Icons.tune_rounded,
              title: 'Availability',
              subtitle: isAvailable ? '🟢 Available for Tasks' : '⚪ Offline',
              onTap: () {
                Navigator.pop(context);
                VolunteerAvailabilityDialog.show(
                  context,
                  isAvailable: isAvailable,
                  onAvailabilityChanged: onAvailabilityChanged,
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.location_on_outlined,
              title: 'Preferred Area',
              subtitle: 'Greater Noida & Koramangala Hub (Within 5 km)',
              onTap: () {},
            ),
            _buildOptionTile(
              context,
              icon: Icons.phone_outlined,
              title: 'Contact Information',
              subtitle: '+91 95556 51225',
              onTap: () {},
            ),
            _buildOptionTile(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'App preferences & notifications',
              onTap: () {},
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

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF64748B)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}
