import 'package:flutter/material.dart';

class ReceiverHelpDialog extends StatelessWidget {
  const ReceiverHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ReceiverHelpDialog(),
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help & Support',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Assistance for verified relief receivers',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSupportTile(
              context,
              icon: Icons.quiz_outlined,
              title: 'FAQs',
              subtitle: 'Find answers to common questions about claiming & pickup.',
              dialogTitle: 'Frequently Asked Questions',
              dialogBody:
                  'Q: How fast can we claim food?\nA: Food is claimed in real-time. Once claimed, an assigned courier or your internal volunteers can pick up within the scheduled window.\n\nQ: Is the food temperature-checked?\nA: Yes, all donating providers log food cooking temperature and packaging types before broadcast.',
            ),
            _buildSupportTile(
              context,
              icon: Icons.support_agent_rounded,
              title: 'Contact Us',
              subtitle: 'Get in touch with our relief operations support desk.',
              dialogTitle: 'Operations Help Desk',
              dialogBody: 'Email: receiver.support@foodflow.org\nPhone: +91 80000 12345 (Available 24/7 during distribution hours)',
            ),
            _buildSupportTile(
              context,
              icon: Icons.bug_report_outlined,
              title: 'Report an Issue',
              subtitle: 'Report a food quality concern or delivery delay to help us improve.',
              dialogTitle: 'Report an Issue',
              dialogBody: 'We take food safety and hygiene seriously. Please contact our safety escalation hotline immediately at safety@foodflow.org.',
            ),
            _buildSupportTile(
              context,
              icon: Icons.auto_awesome_rounded,
              title: 'About Food Flow',
              subtitle: 'Learn about our zero-waste community mission.',
              dialogTitle: 'About Food Flow',
              dialogBody: 'Food Flow bridges the gap between commercial surplus kitchens and verified community shelters, ensuring zero good food goes to waste while nourishing those in need.\n\nMission: Less Food Waste. More Smiles.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String dialogTitle,
    required String dialogBody,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            content: Text(dialogBody, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}
