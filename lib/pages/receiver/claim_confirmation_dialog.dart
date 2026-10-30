import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/supabase_service.dart';
import 'my_claim_details_page.dart';

class ClaimConfirmationDialog extends StatefulWidget {
  final SurplusBatch batch;
  final double distanceKm;
  final VoidCallback? onClaimSuccess;

  const ClaimConfirmationDialog({
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
      barrierDismissible: false,
      builder: (ctx) => ClaimConfirmationDialog(
        batch: batch,
        distanceKm: distanceKm,
        onClaimSuccess: onClaimSuccess,
      ),
    );
  }

  @override
  State<ClaimConfirmationDialog> createState() => _ClaimConfirmationDialogState();
}

class _ClaimConfirmationDialogState extends State<ClaimConfirmationDialog> {
  bool _isClaiming = false;
  String? _errorMessage;

  Future<void> _handleConfirmClaim() async {
    setState(() {
      _isClaiming = true;
      _errorMessage = null;
    });

    try {
      // 0. Expiry safety check
      if (widget.batch.isExpired) {
        setState(() {
          _isClaiming = false;
          _errorMessage = 'Food batch has expired and cannot be claimed.';
        });
        return;
      }

      // 1. Check atomic availability in Supabase to prevent duplicate/race claims
      if (SupabaseService.isInitialized) {
        final checkRow = await SupabaseService.client
            .from('surplus_batches')
            .select('status')
            .eq('id', widget.batch.id)
            .maybeSingle();

        if (checkRow != null && checkRow['status'] != 'available') {
          setState(() {
            _isClaiming = false;
            _errorMessage =
                'This food batch was just claimed by another relief organization. Please choose another available batch.';
          });
          return;
        }
      }

      // 2. Derive receiver organization name from Supabase user session
      final user = SupabaseService.currentUser;
      final meta = user?.userMetadata ?? {};
      final receiverOrg = meta['organization_name'] ??
          meta['full_name'] ??
          meta['name'] ??
          (user?.email?.split('@').first ?? 'Community Relief Center');

      // 3. Process the claim safely
      final success = FoodRescueService.instance.claimBatch(
        batchId: widget.batch.id,
        ngoName: receiverOrg,
        claimedByNgoId: user?.id,
        requestVolunteerCourier: true,
      );

      if (!success) {
        setState(() {
          _isClaiming = false;
          _errorMessage = 'Food batch is no longer available. Please select another donation.';
        });
        return;
      }

      if (mounted) {
        Navigator.pop(context); // Close confirmation modal
        final updatedBatch = FoodRescueService.instance.batches.firstWhere(
          (b) => b.id == widget.batch.id,
          orElse: () => widget.batch,
        );
        widget.onClaimSuccess?.call();
        _showSuccessDialog(context, updatedBatch);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClaiming = false;
          _errorMessage = 'Unable to complete claim right now. Please check your connection.';
        });
      }
    }
  }

  void _showSuccessDialog(BuildContext context, SurplusBatch batch) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC107), width: 2),
                ),
                child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Food Successfully Claimed 🎉',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your claim for ${batch.title} (${batch.quantityPortions} servings) has been registered. The provider has been notified to prepare handover.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🔒 Locked Purchase Value:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '₹${batch.lockedTotalPrice?.toStringAsFixed(0) ?? (batch.dynamicPricing.currentPrice * batch.quantityPortions).toStringAsFixed(0)} (${batch.discountAtPurchase ?? batch.dynamicPricing.discountBadge})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.two_wheeler_rounded, color: Color(0xFF3B82F6), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Volunteer courier assigned for dispatch pickup transit.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyClaimDetailsPage(batch: batch),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'View My Claim',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
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
        constraints: const BoxConstraints(maxWidth: 460),
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
                  child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Claim',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Review donation summary before claiming',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSummaryItem('Food Item', widget.batch.title),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildSummaryItem('Quantity', '${widget.batch.quantityPortions} servings'),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildSummaryItem('Food Type', '${widget.batch.category} • ${widget.batch.dietaryType}'),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildSummaryItem('Provider', widget.batch.providerName),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildSummaryItem('Pickup Time', 'Today, 7:00 PM – 8:00 PM'),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildSummaryItem('Pickup Location', widget.batch.pickupAddress),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildSummaryItem('Instructions', 'Handle with care • Temperature controlled'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Dynamic Pricing & Value Summary Card
            Builder(
              builder: (ctx) {
                final pricing = widget.batch.dynamicPricing;
                final totalBaseVal = widget.batch.basePrice * widget.batch.quantityPortions;
                final totalCurrentVal = pricing.currentPrice * widget.batch.quantityPortions;
                final totalSavedVal = (pricing.youSave * widget.batch.quantityPortions);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFC107)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.lock_rounded, size: 15, color: Color(0xFFB45309)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Price Locked at Claim',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pricing.formattedDiscountBadge,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Original Retail Value',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '₹${totalBaseVal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dynamic Price',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            '₹${totalCurrentVal.toStringAsFixed(0)} (₹${pricing.formattedCurrentPrice}/ea)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Relief NGO Savings',
                            style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Save ₹${totalSavedVal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '🔒 This price is permanently locked into this claim record upon confirmation.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                );
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons: Confirm Claim & Cancel
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isClaiming ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isClaiming ? null : _handleConfirmClaim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isClaiming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B)),
                          )
                        : const Text(
                            'Confirm Claim',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}
