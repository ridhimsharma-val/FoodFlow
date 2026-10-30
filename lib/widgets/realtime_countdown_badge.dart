import 'dart:async';
import 'package:flutter/material.dart';
import '../services/food_rescue_service.dart';

class RealtimeMealCountdownBadge extends StatefulWidget {
  final DateTime safeUntil;
  final BatchStatus status;

  const RealtimeMealCountdownBadge({
    super.key,
    required this.safeUntil,
    required this.status,
  });

  @override
  State<RealtimeMealCountdownBadge> createState() =>
      _RealtimeMealCountdownBadgeState();
}

class _RealtimeMealCountdownBadgeState extends State<RealtimeMealCountdownBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == BatchStatus.delivered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF475569)),
            SizedBox(width: 4),
            Text(
              'Rescued',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = widget.safeUntil.toLocal().difference(DateTime.now());

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
            SizedBox(width: 4),
            Text(
              'Expired',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }

    final totalSeconds = remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final formattedHours = hours.toString().padLeft(2, '0');
    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    if (hours >= 2) {
      // Plenty of time: Emerald
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      textColor = const Color(0xFF047857);
      icon = Icons.timer_outlined;
    } else if (hours >= 1) {
      // Moderate: Amber
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFFB45309);
      icon = Icons.hourglass_top_rounded;
    } else {
      // Urgent < 1 hour: Rose/Red
      bgColor = const Color(0xFFFFF1F2);
      borderColor = const Color(0xFFFECDD3);
      textColor = const Color(0xFFE11D48);
      icon = Icons.alarm_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$formattedHours:$formattedMinutes:$formattedSeconds left',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class RealtimeSafeUntilItem extends StatefulWidget {
  final DateTime safeUntil;
  final String safeTimeFormatted;

  const RealtimeSafeUntilItem({
    super.key,
    required this.safeUntil,
    required this.safeTimeFormatted,
  });

  @override
  State<RealtimeSafeUntilItem> createState() => _RealtimeSafeUntilItemState();
}

class _RealtimeSafeUntilItemState extends State<RealtimeSafeUntilItem> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.safeUntil.toLocal().difference(DateTime.now());
    String timeRemainingText;

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      timeRemainingText = 'Expired';
    } else {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      final seconds = remaining.inSeconds % 60;
      if (hours > 0) {
        timeRemainingText = '${hours}h ${minutes}m ${seconds}s left';
      } else {
        timeRemainingText = '${minutes}m ${seconds}s left';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⌛', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        Text(
          'Safe until ${widget.safeTimeFormatted} ($timeRemainingText)',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
