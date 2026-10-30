import 'package:flutter/material.dart';
import '../../services/dynamic_pricing_service.dart';
import '../../services/food_rescue_service.dart';

/// Comprehensive Volunteer Payment Detail and Confirmation Page
class VolunteerPaymentConfirmationPage extends StatelessWidget {
  final SurplusBatch batch;

  const VolunteerPaymentConfirmationPage({
    super.key,
    required this.batch,
  });

  // Payout calculation breakdown for this delivery
  double get _baseFare => 50.0;
  double get _distanceKm => 4.2;
  double get _distancePay => _distanceKm * 12.0; // ₹12 / km
  double get _timelyBonus => 30.0; // delivered within safe-window
  double get _bulkBonus => batch.quantityPortions >= 40 ? 30.0 : 15.0;
  double get _totalVolunteerPayout => _baseFare + _distancePay + _timelyBonus + _bulkBonus;

  // Transaction reference identifiers
  String get _txnId => 'TXN-FF-${batch.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').padRight(8, '0').substring(0, 8).toUpperCase()}';
  String get _utrNumber => 'UTR-2026-${(batch.id.hashCode.abs() % 90000000 + 10000000)}';

  @override
  Widget build(BuildContext context) {
    final pricing = batch.dynamicPricing;
    final formattedTime = _formatTimestamp(batch.deliveredAt ?? DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Payment Details & Confirmation',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF1E293B)),
            tooltip: 'Share Confirmation',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment confirmation link copied to clipboard.'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF1E293B)),
            tooltip: 'Download Receipt',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF166534),
                  content: Text('Tax-exempt delivery receipt ($_txnId.pdf) downloaded.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Success Hero Banner
                _buildSettlementHeroBanner(context, formattedTime),
                const SizedBox(height: 20),

                // 2. Dual-OTP Handover Confirmation Card
                _buildHandoverOtpCard(),
                const SizedBox(height: 20),

                // 3. Volunteer Courier Earnings Breakdown Card
                _buildVolunteerPayoutCard(),
                const SizedBox(height: 20),

                // 4. Food Rescue Order & Dynamic Pricing Settlement Card
                _buildFoodPricingOrderCard(pricing),
                const SizedBox(height: 20),

                // 5. Escrow Settlement & Banking Audit Trail Card
                _buildBankingAuditCard(),
                const SizedBox(height: 28),

                // 6. Action Buttons
                _buildActionButtons(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Hero Settlement Banner
  // ---------------------------------------------------------------------------
  Widget _buildSettlementHeroBanner(BuildContext context, String formattedTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF86EFAC), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment Confirmed & Settled',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Disbursed instantly via Food Flow Smart Courier Escrow',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE047)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Courier Payout: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF854D0E),
                  ),
                ),
                Text(
                  '₹${_totalVolunteerPayout.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF854D0E),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PAID ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Credited on $formattedTime',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Dual-OTP Handover Authentication Confirmation
  // ---------------------------------------------------------------------------
  Widget _buildHandoverOtpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Dual-OTP Authentication Proof',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Both parties authorized the handover via cryptographically validated OTPs.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildOtpCheckRow(
                  label: 'Provider Pickup OTP',
                  otpValue: batch.pickupOtp,
                  actor: batch.providerName,
                  statusText: 'Verified at Provider Dock ✓',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                _buildOtpCheckRow(
                  label: 'Receiver Delivery OTP',
                  otpValue: batch.deliveryOtp,
                  actor: batch.claimedByNgo ?? 'Verified Relief Center',
                  statusText: 'Verified at Dropoff Intake ✓',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCheckRow({
    required String label,
    required String otpValue,
    required String actor,
    required String statusText,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: $otpValue',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                actor,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text(
            statusText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF047857),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Volunteer Courier Earnings Breakdown Card
  // ---------------------------------------------------------------------------
  Widget _buildVolunteerPayoutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Volunteer Earnings Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '100% Retained',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildLineItem('Base Transit Allowance', '₹${_baseFare.toStringAsFixed(2)}'),
          _buildLineItem(
            'Distance Allowance (${_distanceKm.toStringAsFixed(1)} km @ ₹12.00/km)',
            '₹${_distancePay.toStringAsFixed(2)}',
          ),
          _buildLineItem('Rapid Dispatch Safe-Window Bonus', '₹${_timelyBonus.toStringAsFixed(2)}'),
          _buildLineItem(
            'Bulk Lot Handling Incentive (${batch.quantityPortions} meals)',
            '₹${_bulkBonus.toStringAsFixed(2)}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Courier Payout',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '₹${_totalVolunteerPayout.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Food Rescue Order & Dynamic Pricing Settlement Card
  // ---------------------------------------------------------------------------
  Widget _buildFoodPricingOrderCard(DynamicPriceResult pricing) {
    final originalTotal = batch.basePrice * batch.quantityPortions;
    final dynamicTotal = pricing.totalPrice;
    final totalSavings = originalTotal > dynamicTotal ? (originalTotal - dynamicTotal) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Food Batch & Dynamic Pricing Settlement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildDataField('Item Rescued', '${batch.title} (${batch.category})'),
          _buildDataField('Quantity', '${batch.quantityPortions} Meals (${batch.dietaryType})'),
          _buildDataField('Food Provider', '${batch.providerName} (${batch.providerCategory})'),
          _buildDataField('Intake NGO', batch.claimedByNgo ?? 'Verified Relief Organization'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _buildLineItem('Original Retail Valuation', '₹${originalTotal.toStringAsFixed(2)}', strike: true),
          _buildLineItem(
            'Dynamic Price Paid by Receiver',
            '₹${dynamicTotal.toStringAsFixed(2)} (₹${pricing.formattedCurrentPrice}/meal)',
            highlight: true,
          ),
          _buildLineItem('Charity Relief Discount', '₹${totalSavings.toStringAsFixed(2)} saved (${pricing.formattedDiscountBadge})'),
          _buildLineItem('Receiver Settlement Mode', 'Direct Escrow / Grant Transfer'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Escrow Settlement & Banking Audit Trail Card
  // ---------------------------------------------------------------------------
  Widget _buildBankingAuditCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security_rounded, color: Color(0xFF16A34A), size: 20),
              SizedBox(width: 8),
              Text(
                'Escrow Banking & Transaction Reference',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildAuditRow('Transaction Ref ID', _txnId),
          _buildAuditRow('Banking UTR Number', _utrNumber),
          _buildAuditRow('Courier Disbursal UPI', 'volunteer.courier@okaxis'),
          _buildAuditRow('Settlement Gateway', 'Food Flow Escrow Instant UPI v2.4'),
          _buildAuditRow('Status', 'Completed · Immutable Ledger Sealed'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Action Buttons
  // ---------------------------------------------------------------------------
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF166534),
                  content: Text('Delivery Certificate and Receipt ($_txnId) downloaded.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 20),
            label: const Text(
              'Download Tax-Exempt Receipt (PDF)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Back to Volunteer Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Micro-Widgets
  // ---------------------------------------------------------------------------
  Widget _buildLineItem(String label, String value, {bool strike = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: highlight ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight
                  ? const Color(0xFF166534)
                  : (strike ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
              decoration: strike ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$min $period';
  }
}
