import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_drawer.dart';

class ProviderProfileDialog extends StatelessWidget {
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

  static void show(
    BuildContext context, {
    required String providerName,
    required String category,
    required String location,
    VoidCallback? onProfileUpdated,
    VoidCallback? onSwitchRole,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Profile Card
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFFFC107),
                  child: Text(
                    providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        providerName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location.isNotEmpty ? location : 'Greater Noida',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Statistics Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          '1,240',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Meals Donated',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          '98%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Successful Pickups',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Options List
            _buildOptionTile(
              icon: Icons.edit_note_rounded,
              title: 'Edit Profile',
              subtitle: 'Update business name and legal representative',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editor is available in side menu.')),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.access_time_rounded,
              title: 'Operating Hours',
              subtitle: 'Mon – Sun: 10:00 AM – 11:30 PM',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.store_mall_directory_rounded,
              title: 'Pickup Location',
              subtitle: location.isNotEmpty ? location : 'Main Service Dock',
              onTap: () {},
            ),
            _buildOptionTile(
              icon: Icons.contact_phone_rounded,
              title: 'Contact Information',
              subtitle: SupabaseService.currentUser?.email ?? 'contact@foodflow.org',
              onTap: () {},
            ),
            if (onSwitchRole != null)
              _buildOptionTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Switch Role / Portal',
                subtitle: 'Switch to Receiver (NGO) or Volunteer Squad',
                onTap: () {
                  Navigator.pop(context);
                  onSwitchRole!();
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  AppDrawer.confirmAndSignOut(context);
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out of Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1E293B), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
      onTap: onTap,
    );
  }
}
