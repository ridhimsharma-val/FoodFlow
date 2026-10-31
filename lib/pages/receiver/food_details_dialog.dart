import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import 'claim_confirmation_dialog.dart';
import 'receiver_provider_details_dialog.dart';

class FoodDetailsDialog extends StatefulWidget {
  final SurplusBatch batch;
  final double distanceKm;
  final VoidCallback? onClaimSuccess;

  const FoodDetailsDialog({
    super.key,
    required this.batch,
    required this.distanceKm,
    this.onClaimSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required SurplusBatch batch,
    required double distanceKm,
    VoidCallback? onClaimSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FoodDetailsDialog(
        batch: batch,
        distanceKm: distanceKm,
        onClaimSuccess: onClaimSuccess,
      ),
    );
  }

  @override
  State<FoodDetailsDialog> createState() => _FoodDetailsDialogState();
}

class _FoodDetailsDialogState extends State<FoodDetailsDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1-second periodic timer for live dynamic countdown without DB writes
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final batch = FoodRescueService.instance.batches.firstWhere(
      (b) => b.id == widget.batch.id,
      orElse: () => widget.batch,
    );
    final pricing = batch.dynamicPricing;
    final isExpired = batch.isExpired || pricing.isExpired;
    final isClaimed = batch.status != BatchStatus.available && !isExpired;

    final cookedTimeStr = _formatTime(batch.cookedAt);
    final safeTimeStr = _formatTime(batch.safeUntil);
    final isVeg = batch.dietaryType.toLowerCase().contains('veg') &&
        !batch.dietaryType.toLowerCase().contains('non');

    final totalCurrentPrice = pricing.currentPrice * batch.quantityPortions;
    final totalBasePrice = batch.basePrice * batch.quantityPortions;
    final totalSavings = (pricing.youSave * batch.quantityPortions);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Image Banner with Close Button
              Stack(
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isExpired ? '⌛' : batch.foodEmoji, style: const TextStyle(fontSize: 48)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isExpired
                                  ? const Color(0xFFFCA5A5)
                                  : (isVeg ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isExpired
                                      ? Icons.warning_rounded
                                      : (isVeg ? Icons.eco_rounded : Icons.restaurant_rounded),
                                  size: 13,
                                  color: isExpired
                                      ? const Color(0xFF7F1D1D)
                                      : (isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isExpired ? 'EXPIRED' : batch.dietaryType,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isExpired
                                        ? const Color(0xFF7F1D1D)
                                        : (isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      radius: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Servings Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            batch.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFC107)),
                          ),
                          child: Text(
                            '${batch.quantityPortions} servings',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${batch.category} • Cooked Meal',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),

                    // Already Claimed Notice Banner
                    if (isClaimed) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFFB45309), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Claimed by ${batch.claimedByNgo ?? "a verified relief partner"} • Handover in progress',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Smart Dynamic Markdown Price Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isExpired ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isExpired ? const Color(0xFFFCA5A5) : const Color(0xFFFFC107).withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_graph_rounded,
                                    size: 16,
                                    color: isExpired ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Smart Markdown Pricing',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isExpired ? 'EXPIRED' : pricing.formattedDiscountBadge,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isExpired ? const Color(0xFFDC2626) : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isExpired) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.dangerous_rounded, color: Color(0xFFDC2626), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Safe consumption window expired. Food is ₹0 and cannot be claimed.',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₹${pricing.formattedBasePrice}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF94A3B8),
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${pricing.formattedCurrentPrice}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Text(
                                  ' / portion',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total: ₹${totalCurrentPrice.toStringAsFixed(0)} (Orig: ₹${totalBasePrice.toStringAsFixed(0)})',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Save: ₹${totalSavings.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Countdown indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Safe countdown: ${pricing.formattedCountdown} left ${batch.formatSafeUntilTarget()}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                    ),
                                  ),
                                  Text(
                                    '${(pricing.percentRemaining * 100).toStringAsFixed(0)}% Fresh',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Provider Card
                    InkWell(
                      onTap: () {
                        ReceiverProviderDetailsDialog.show(
                          context,
                          providerName: batch.providerName,
                          providerCategory: batch.providerCategory,
                          location: batch.pickupAddress,
                          distanceKm: widget.distanceKm,
                          activePortions: batch.quantityPortions,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        batch.providerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF3B82F6)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${batch.providerCategory} • ${widget.distanceKm.toStringAsFixed(1)} km away',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Key Food Timings & Details Grid
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            label: 'Prepared',
                            value: cookedTimeStr,
                          ),
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.hourglass_bottom_rounded,
                            iconColor: const Color(0xFFEF4444),
                            label: 'Best consumed before',
                            value: safeTimeStr,
                          ),
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.schedule_rounded,
                            iconColor: const Color(0xFFD97706),
                            label: 'Pickup Window',
                            value: 'Today, 7:00 PM – 8:00 PM',
                          ),
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.place_rounded,
                            iconColor: const Color(0xFF10B981),
                            label: 'Pickup Location',
                            value: batch.pickupAddress,
                          ),
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            label: 'Special Instructions',
                            value: 'Handle with care • Temperature controlled (${batch.temperatureCelsius}°C)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Primary Action: Claim Food
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: (isClaimed || isExpired)
                            ? null
                            : () {
                                Navigator.pop(context);
                                ClaimConfirmationDialog.show(
                                  context,
                                  batch: batch,
                                  distanceKm: widget.distanceKm,
                                  onClaimSuccess: widget.onClaimSuccess,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: const Color(0xFF1E293B),
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          isExpired
                              ? Icons.block_rounded
                              : (isClaimed ? Icons.check_circle_rounded : Icons.volunteer_activism_rounded),
                          size: 20,
                        ),
                        label: Text(
                          isExpired
                              ? 'Food Expired (Unclaimable)'
                              : (isClaimed ? 'Already Claimed' : 'Claim Food'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}
