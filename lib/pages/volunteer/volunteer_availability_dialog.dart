import 'package:flutter/material.dart';

class VolunteerAvailabilityDialog extends StatefulWidget {
  final bool initialIsAvailable;
  final ValueChanged<bool> onAvailabilityChanged;

  const VolunteerAvailabilityDialog({
    super.key,
    required this.initialIsAvailable,
    required this.onAvailabilityChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isAvailable,
    required ValueChanged<bool> onAvailabilityChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VolunteerAvailabilityDialog(
        initialIsAvailable: isAvailable,
        onAvailabilityChanged: onAvailabilityChanged,
      ),
    );
  }

  @override
  State<VolunteerAvailabilityDialog> createState() => _VolunteerAvailabilityDialogState();
}

class _VolunteerAvailabilityDialogState extends State<VolunteerAvailabilityDialog> {
  late bool _isAvailable;
  String _preferredTime = 'Evening';
  String _preferredRadius = 'Within 5 km';

  @override
  void initState() {
    super.initState();
    _isAvailable = widget.initialIsAvailable;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Color(0xFFD97706), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Availability Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Master Toggle
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isAvailable ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isAvailable ? const Color(0xFFFFC107) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isAvailable ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isAvailable ? Icons.check_rounded : Icons.power_settings_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAvailable ? 'Available for Delivery' : 'Currently Offline',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          _isAvailable
                              ? 'Ready to accept food rescue missions'
                              : 'Standby mode: new tasks will not be assigned',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAvailable,
                    activeThumbColor: const Color(0xFFD97706),
                    activeTrackColor: const Color(0xFFFFC107).withValues(alpha: 0.5),
                    onChanged: (val) {
                      setState(() => _isAvailable = val);
                      widget.onAvailabilityChanged(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Preferred Operating Hours
            const Text(
              'Preferred Operating Hours',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Morning', 'Afternoon', 'Evening'].map((time) {
                final isSel = _preferredTime == time;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSel,
                  onSelected: (_) => setState(() => _preferredTime = time),
                  selectedColor: const Color(0xFFFEF3C7),
                  backgroundColor: const Color(0xFFF8FAFC),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? const Color(0xFFB45309) : const Color(0xFF64748B),
                  ),
                  side: BorderSide(
                    color: isSel ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Preferred Radius
            const Text(
              'Preferred Delivery Radius',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Within 5 km', 'Within 10 km', 'Any nearby area'].map((radius) {
                final isSel = _preferredRadius == radius;
                return ChoiceChip(
                  label: Text(radius),
                  selected: isSel,
                  onSelected: (_) => setState(() => _preferredRadius = radius),
                  selectedColor: const Color(0xFFFEF3C7),
                  backgroundColor: const Color(0xFFF8FAFC),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? const Color(0xFFB45309) : const Color(0xFF64748B),
                  ),
                  side: BorderSide(
                    color: isSel ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
