import 'package:flutter/material.dart';
import '../login.dart';
import '../services/consent_service.dart';
import 'brand_logo.dart';

/// Supported legal document types
enum LegalDocumentType {
  termsAndConditions,
  privacyPolicy,
}

/// Modal/Bottom Sheet interface for reviewing and accepting Food Flow
/// Terms & Conditions and the separate Privacy Policy.
class TermsAndConditionsDialog extends StatefulWidget {
  final LegalDocumentType documentType;
  final int initialTargetSection;
  final bool isBottomSheet;

  const TermsAndConditionsDialog({
    super.key,
    this.documentType = LegalDocumentType.termsAndConditions,
    this.initialTargetSection = 1,
    this.isBottomSheet = false,
  });

  /// Opens the Terms & Conditions document
  static Future<bool?> showTerms(BuildContext context) {
    return show(context, documentType: LegalDocumentType.termsAndConditions);
  }

  /// Opens the Privacy Policy document
  static Future<bool?> showPrivacy(BuildContext context) {
    return show(context, documentType: LegalDocumentType.privacyPolicy);
  }

  /// Opens the dialog as a responsive centered modal (Desktop) or bottom sheet (Mobile)
  static Future<bool?> show(
    BuildContext context, {
    LegalDocumentType documentType = LegalDocumentType.termsAndConditions,
    int initialTargetSection = 1,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 650;

    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
            ),
            child: TermsAndConditionsDialog(
              documentType: documentType,
              initialTargetSection: initialTargetSection,
              isBottomSheet: true,
            ),
          ),
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: TermsAndConditionsDialog(
              documentType: documentType,
              initialTargetSection: initialTargetSection,
              isBottomSheet: false,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<TermsAndConditionsDialog> createState() => _TermsAndConditionsDialogState();
}

class _TermsAndConditionsDialogState extends State<TermsAndConditionsDialog> {
  final ScrollController _scrollController = ScrollController();
  late LegalDocumentType _currentDoc;

  bool _hasReachedBottom = false;
  bool _isAccepted = false;
  bool _isAutoClosing = false;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.documentType;
    _isAccepted = FoodFlowConsentService.instance.hasAcceptedCurrentTermsSync();
    _checkInitialReviewStatus();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkIfScrolledToBottom();
    });
  }

  void _checkInitialReviewStatus() {
    if (_currentDoc == LegalDocumentType.termsAndConditions) {
      _hasReachedBottom = FoodFlowConsentService.instance.hasReadTerms;
    } else {
      _hasReachedBottom = FoodFlowConsentService.instance.hasReadPrivacy;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _checkIfScrolledToBottom();
  }

  void _checkIfScrolledToBottom() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= (maxScroll - 32) || maxScroll <= 0) {
      if (!_hasReachedBottom) {
        setState(() {
          _hasReachedBottom = true;
        });
      }
      if (_currentDoc == LegalDocumentType.termsAndConditions) {
        FoodFlowConsentService.instance.markTermsAsRead();
      } else {
        FoodFlowConsentService.instance.markPrivacyAsRead();
      }
    }
  }

  void _switchDocument(LegalDocumentType targetDoc) {
    setState(() {
      _currentDoc = targetDoc;
      _checkInitialReviewStatus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _checkIfScrolledToBottom();
    });
  }

  Future<void> _handleConsentChanged(bool? value) async {
    if (_isAutoClosing) return;
    final accept = value == true;
    setState(() {
      _isAccepted = accept;
    });

    if (accept) {
      _isAutoClosing = true;
      await FoodFlowConsentService.instance.recordConsent();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      await FoodFlowConsentService.instance.revokeConsent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = widget.isBottomSheet ? viewportHeight * 0.92 : viewportHeight * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Fixed Close Button
          _buildHeader(context),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // Scrollable Document Content
          Flexible(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentDoc == LegalDocumentType.termsAndConditions)
                      ..._buildTermsContent()
                    else
                      ..._buildPrivacyContent(),

                    const SizedBox(height: 24),
                    const Divider(color: AppColors.borderSubtle, thickness: 1.2),
                    const SizedBox(height: 16),

                    // User Acknowledgement Gate Section
                    _buildAcknowledgementSection(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isTerms = _currentDoc == LegalDocumentType.termsAndConditions;
    final title = isTerms ? 'TERMS & CONDITIONS' : 'PRIVACY POLICY';
    final subtitle = isTerms ? 'Platform Agreement & Operating Terms' : 'Data Processing & Privacy Notice';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.logoBoxBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderDashedLogo, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FoodFlowIcon(size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Food Flow',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLogo,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTerms ? AppColors.ruleBannerBackground : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTerms ? AppColors.borderRuleBanner : const Color(0xFFBAE6FD),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isTerms ? 'Operating Terms' : 'DPDP Privacy Notice',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isTerms ? AppColors.textRule : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () {
              Navigator.of(context).pop(_isAccepted);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 1. TERMS & CONDITIONS (Original 8 Sections Preserved)
  // ============================================================================
  List<Widget> _buildTermsContent() {
    return [
      _buildSectionTitle('1. Platform Role & Legal Responsibilities'),
      _buildParagraph(
        'Food Flow is a technology and coordination platform connecting food donors, '
        'recipient organisations and volunteers to facilitate the responsible redistribution '
        'of surplus food.',
      ),
      _buildBullet('Food Flow acts as a technology platform connecting Providers, Receivers and Volunteers.'),
      _buildBullet('Food Flow does not ordinarily prepare, own, inspect, certify, package or physically transport food listed by independent users.'),
      _buildBullet('Providers, Receivers and Volunteers remain responsible for their respective activities and applicable legal obligations.'),
      _buildBullet('Food Flow does not guarantee the safety, quality, availability or condition of food listed by independent users.'),
      const SizedBox(height: 20),

      _buildSectionTitle('2. Food Safety & Regulatory Compliance'),
      _buildSubheading('Providers agree to:'),
      _buildBullet('List only food that is safe and suitable for redistribution.'),
      _buildBullet('Provide accurate food details, quantity, preparation time and safe-consumption deadline.'),
      _buildBullet('Maintain appropriate hygiene, packaging and storage conditions.'),
      _buildBullet('Disclose relevant ingredients and known allergens.'),
      _buildBullet('Comply with applicable FSSAI licensing, registration and food-safety requirements.'),
      const SizedBox(height: 8),

      _buildSubheading('Receivers agree to:'),
      _buildBullet('Collect food within the permitted safe-use period.'),
      _buildBullet('Maintain suitable storage and handling conditions.'),
      _buildBullet('Follow applicable food-safety and hygiene requirements.'),
      const SizedBox(height: 8),

      _buildSubheading('Volunteers agree to:'),
      _buildBullet('Transport food responsibly and within the specified time.'),
      _buildBullet('Maintain appropriate hygienic handling and temperature conditions.'),
      _buildBullet('Follow verified pickup and delivery procedures.'),
      const SizedBox(height: 20),

      _buildSectionTitle('3. Claims, Pickup & Delivery Verification'),
      _buildBullet('Food claims are subject to availability and confirmation through the platform.'),
      _buildBullet('Volunteers must accept a pickup before the rescue is treated as assigned.'),
      _buildBullet('Pickup and delivery OTPs are used to verify physical handovers.'),
      _buildBullet('Users must not share OTPs with unauthorised persons.'),
      _buildBullet('Incorrect or unauthorised verification attempts may be rejected or restricted.'),
      _buildBullet('Users must not falsely report a pickup or delivery as completed.'),
      const SizedBox(height: 20),

      _buildSectionTitle('4. Personal Data Collection & Usage'),
      _buildParagraph('Food Flow may collect information necessary to operate the platform, including:'),
      _buildBullet('Name and account information.'),
      _buildBullet('Phone number and email address.'),
      _buildBullet('Organisation and business details.'),
      _buildBullet('Pickup and delivery addresses.'),
      _buildBullet('Location and GPS coordinates during active rescues.'),
      _buildBullet('Food listings, claims and delivery records.'),
      _buildBullet('Authentication, security and activity records.'),
      const SizedBox(height: 8),
      _buildSubheading('This information is used for:'),
      _buildBullet('Account creation and verification.'),
      _buildBullet('Matching donors with suitable recipients.'),
      _buildBullet('Coordinating pickups and deliveries.'),
      _buildBullet('Providing live tracking and rescue updates.'),
      _buildBullet('Preventing misuse and maintaining platform security.'),
      _buildBullet('Resolving support requests and legitimate disputes.'),
      const SizedBox(height: 20),

      _buildSectionTitle('5. Data Sharing & Privacy Protection'),
      _buildParagraph(
        'Your personal information is not sold or rented by Food Flow.',
        isBold: true,
      ),
      _buildBullet('Personal information is shared when necessary to operate the service, fulfil a rescue or meet legal obligations.'),
      _buildBullet('Contact details and relevant addresses may be shared with authorised participants involved in a particular rescue.'),
      _buildBullet('A volunteer\'s live location may be visible to the relevant Provider and Receiver during an active delivery.'),
      _buildBullet('Personal information is not intended for public display.'),
      _buildBullet('Necessary service providers, such as hosting, authentication, communication and mapping providers, may process limited information to support the platform.'),
      const SizedBox(height: 20),

      _buildSectionTitle('6. Data Security & Retention'),
      _buildParagraph(
        'Food Flow applies reasonable technical and organisational safeguards to protect user '
        'information against unauthorised access, misuse, alteration and disclosure. '
        'These include access restrictions, role-based permissions and appropriate security controls.',
      ),
      _buildBullet('User information is accessed only for authorised purposes.'),
      _buildBullet('Information is retained only as long as reasonably necessary for platform operations, dispute resolution and applicable legal requirements.'),
      _buildBullet('Users may raise requests concerning their personal information through available support channels.'),
      _buildBullet('In case of a personal data breach, Food Flow will follow applicable notification and response obligations.'),
      _buildParagraph(
        'No online platform can guarantee absolute protection against every possible security incident.',
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 20),

      _buildSectionTitle('7. Misuse, Suspension & Liability'),
      _buildBullet('Fake accounts, misleading listings, fraudulent claims and misuse of the platform are prohibited.'),
      _buildBullet('Food Flow may restrict or suspend accounts involved in fraudulent, unsafe or unauthorised activities.'),
      _buildBullet('Each participant remains responsible for their own actions, statements, food handling and compliance with applicable laws.'),
      _buildBullet('To the extent permitted by law, Food Flow is not responsible for independent users\' food-handling conduct, inaccurate listings, failure to collect food or delivery delays.'),
      _buildBullet('Nothing in these terms removes any statutory responsibility or liability that cannot legally be excluded.'),
      const SizedBox(height: 20),

      _buildSectionTitle('8. Agreement & Updates'),
      _buildParagraph(
        'These terms apply to the use of Food Flow and may be updated to reflect changes in platform functionality or applicable regulations.',
      ),
      _buildParagraph(
        'Material changes will be communicated through appropriate platform channels.',
      ),
      _buildParagraph(
        'By accepting these terms, you confirm that you have read and understood this agreement and agree to follow it while using Food Flow.',
      ),
    ];
  }

  // ============================================================================
  // 2. PRIVACY POLICY (Distinct 11 Sections focused on data, GPS & DPDP)
  // ============================================================================
  List<Widget> _buildPrivacyContent() {
    return [
      _buildSectionTitle('1. Introduction'),
      _buildParagraph(
        'Food Flow operates a logistics coordination platform facilitating the rescue and responsible redistribution '
        'of surplus food between registered Food Providers, charitable Receivers, and dispatch Volunteers. '
        'We respect your privacy and process personal information strictly in accordance with applicable Indian laws, '
        'including the Digital Personal Data Protection Act, 2023 (DPDP Act) and relevant rules as notified.',
      ),
      _buildParagraph(
        'This Privacy Policy describes what information we collect, how it is processed, with whom it is operationally shared, '
        'how we safeguard your data, and how you may exercise your statutory privacy choices.',
      ),
      const SizedBox(height: 20),

      _buildSectionTitle('2. Information We Collect'),
      _buildParagraph('We collect personal data directly from you and through your active use of the Food Flow application:'),
      _buildBullet('Account Details: Name, email address, phone number, designated role (Provider, Receiver, or Volunteer), and authentication records.'),
      _buildBullet('Organization Information: Registered entity name, FSSAI registration/license number (where applicable), kitchen/facility category, operating hours, and authorized contact person.'),
      _buildBullet('Rescue & Transaction Logs: Surplus batch listings, portion counts, pickup addresses, dietary attributes, claim details, verification timestamps, and dual-OTP handovers.'),
      _buildBullet('Transit Geolocation: Physical pickup and delivery addresses, and real-time GPS coordinates of Volunteers during active deliveries.'),
      _buildBullet('Device & Platform Metrics: Operating system version, device identifiers, and crash diagnostics necessary to maintain secure connectivity and reliable dispatch operations.'),
      const SizedBox(height: 20),

      _buildSectionTitle('3. How We Use Your Information'),
      _buildParagraph('Your personal data is used solely for legitimate operational purposes:'),
      _buildBullet('Authenticating user sessions and providing role-tailored dashboards.'),
      _buildBullet('Matching food donors with nearby charitable recipients to minimize food wastage.'),
      _buildBullet('Dispatching and coordinating volunteer rescue assignments in real time.'),
      _buildBullet('Verifying physical custody handovers using 6-digit cryptographic pickup and delivery OTPs.'),
      _buildBullet('Auditing food rescue milestones, tracking CO₂ reduction impact metrics, and resolving operational disputes.'),
      _buildBullet('Preventing fraudulent accounts, spurious food listings, or unauthorized access attempts.'),
      const SizedBox(height: 20),

      _buildSectionTitle('4. Location & Live GPS Privacy'),
      _buildParagraph(
        'Location information is fundamental to real-time redistribution logistics:',
        isBold: true,
      ),
      _buildBullet('Pickup & Delivery Points: Addresses provided by Providers and Receivers are shared strictly with participants assigned to that specific rescue task.'),
      _buildBullet('Live Volunteer Tracking: A volunteer\'s real-time transit location is collected only while an assigned rescue task is active (from acceptance to completion).'),
      _buildBullet('Restricted Visibility: Real-time courier movement is visible exclusively to the donor and receiver involved in that particular rescue and is never publicly broadcast or sold.'),
      _buildBullet('Background Location: Volunteers may toggle availability status to "Offline" at any time, which halts dispatch matching and location collection.'),
      const SizedBox(height: 20),

      _buildSectionTitle('5. Data Sharing & Disclosure'),
      _buildParagraph(
        'Food Flow does not sell, rent, or trade your personal information.',
        isBold: true,
      ),
      _buildParagraph('Personal data is disclosed strictly under the following limited circumstances:'),
      _buildBullet('Rescue Coordination: Relevant contact names, telephone numbers, and addresses are shared between the matched Provider, Receiver, and assigned Volunteer for the active task duration.'),
      _buildBullet('Technical Infrastructure Providers: Secure cloud hosting (Supabase), SMS/email notification dispatchers, and map tile services operating under strict confidentiality and data protection obligations.'),
      _buildBullet('Legal & Regulatory Obligations: When mandated by applicable statutory authority, judicial warrant, or law enforcement investigation, or to protect individual life and physical safety.'),
      const SizedBox(height: 20),

      _buildSectionTitle('6. Data Security'),
      _buildParagraph(
        'We maintain reasonable administrative, technical, and organizational safeguards designed to protect personal data '
        'against unauthorized access, alteration, disclosure, or accidental destruction. Safeguards include row-level access '
        'controls (RLS), transport layer security (TLS/HTTPS), encrypted credential storage, and session token timeouts.',
      ),
      _buildParagraph(
        'While we follow recognized security standards, no online service can guarantee absolute security against all unforeseen vulnerabilities.',
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 20),

      _buildSectionTitle('7. Data Retention & Deletion'),
      _buildBullet('Account data is retained for the duration of your active profile on Food Flow.'),
      _buildBullet('Rescue histories, dual-OTP handover receipts, and impact calculations are retained for legitimate audit trails and statutory recordkeeping requirements.'),
      _buildBullet('Users may request account deactivation and data deletion through our support channels. Data will be safely erased or anonymized, subject to mandatory regulatory retention requirements.'),
      const SizedBox(height: 20),

      _buildSectionTitle('8. Your Privacy Rights & Choices'),
      _buildParagraph('Under the applicable data protection framework in India, you are entitled to:'),
      _buildBullet('Review and Update: Access and edit your profile, organization details, and contact numbers directly in the app.'),
      _buildBullet('Consent Revocation: Withdraw or modify active consent by unchecking the acknowledgement setting in your profile.'),
      _buildBullet('Grievance Redressal: Lodge inquiries or complaints regarding the processing of your personal information with our designated Grievance Officer.'),
      _buildBullet('Nomination: Nominate an authorized representative in accordance with DPDP rules to manage your personal data in the event of death or incapacity.'),
      const SizedBox(height: 20),

      _buildSectionTitle('9. Children\'s Information'),
      _buildParagraph(
        'Food Flow is intended strictly for authorized representatives of commercial donors, verified NGOs, '
        'and volunteer adults aged 18 and older. We do not knowingly solicit or collect personal information from minors. '
        'If it comes to our attention that data of a minor was inadvertently collected, it will be promptly removed.',
      ),
      const SizedBox(height: 20),

      _buildSectionTitle('10. Changes to This Privacy Policy'),
      _buildParagraph(
        'We may update this Privacy Policy from time to time to reflect operational enhancements, new platform features, '
        'or evolving regulatory requirements under Indian law.',
      ),
      _buildParagraph(
        'Material updates will be communicated through in-app notifications or designated email communications prior to taking effect.',
      ),
      const SizedBox(height: 20),

      _buildSectionTitle('11. Contact & Grievance Redressal'),
      _buildParagraph(
        'For questions, privacy inquiries, or statutory grievance redressal under the Digital Personal Data Protection Act, '
        'please contact our designated Grievance Officer using the configuration details below:',
      ),
      _buildBullet('Platform: Food Flow Surplus Food Redistribution System'),
      _buildBullet('Grievance Officer: [Configured Grievance Officer - Food Flow Operations]'),
      _buildBullet('Official Email: [privacy@foodflow.org / grievance@foodflow.org]'),
      _buildBullet('Postal Address: [Food Flow Platform Operations, Bengaluru, Karnataka 560038, India]'),
      _buildBullet('Resolution Timeline: Grievances are acknowledged and resolved within the statutory period prescribed under Indian DPDP regulations.'),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSubheading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, {bool isBold = false, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: style ??
            TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGoldDark,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // USER ACKNOWLEDGEMENT GATE (Requires BOTH Documents to be Reviewed)
  // ============================================================================
  Widget _buildAcknowledgementSection() {
    final hasReadTerms = FoodFlowConsentService.instance.hasReadTerms;
    final hasReadPrivacy = FoodFlowConsentService.instance.hasReadPrivacy;
    final hasReadBoth = hasReadTerms && hasReadPrivacy;
    final isTerms = _currentDoc == LegalDocumentType.termsAndConditions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasReadBoth ? AppColors.pageBackground : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasReadBoth ? AppColors.borderRuleBanner : AppColors.borderSubtle,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'LEGAL DOCUMENT REVIEW PROGRESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasReadBoth ? AppColors.ruleBannerBackground : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: hasReadBoth ? Border.all(color: AppColors.borderRuleBanner) : null,
                ),
                child: Text(
                  hasReadBoth ? 'Both Documents Reviewed ✓' : '2 Documents Required',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: hasReadBoth ? AppColors.textRule : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Two Document Check Badges
          Row(
            children: [
              Expanded(
                child: _buildDocStatusPill(
                  label: 'Terms & Conditions',
                  isRead: hasReadTerms,
                  isCurrent: isTerms,
                  onTap: isTerms ? null : () => _switchDocument(LegalDocumentType.termsAndConditions),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDocStatusPill(
                  label: 'Privacy Policy',
                  isRead: hasReadPrivacy,
                  isCurrent: !isTerms,
                  onTap: !isTerms ? null : () => _switchDocument(LegalDocumentType.privacyPolicy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Checkbox (Enabled ONLY when BOTH documents have been read to bottom)
          InkWell(
            onTap: hasReadBoth && !_isAutoClosing
                ? () => _handleConsentChanged(!_isAccepted)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _isAccepted,
                  activeColor: AppColors.primaryGold,
                  checkColor: Colors.black87,
                  onChanged: hasReadBoth && !_isAutoClosing
                      ? _handleConsentChanged
                      : null,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'I have read and agree to the Terms & Conditions and acknowledge the Privacy Notice.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!hasReadBoth) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                !hasReadTerms && !hasReadPrivacy
                    ? 'Please scroll to the bottom of both documents to unlock acceptance.'
                    : (!hasReadTerms
                        ? 'Please switch to and read Terms & Conditions to unlock acceptance.'
                        : 'Please switch to and read Privacy Policy to unlock acceptance.'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Shortcut button to open the other unread document
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (isTerms) {
                    _switchDocument(LegalDocumentType.privacyPolicy);
                  } else {
                    _switchDocument(LegalDocumentType.termsAndConditions);
                  }
                },
                icon: Icon(
                  isTerms ? Icons.privacy_tip_outlined : Icons.description_outlined,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                label: Text(
                  isTerms ? 'Review Privacy Policy ➔' : 'Review Terms & Conditions ➔',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderRuleBanner, width: 1.2),
                  backgroundColor: AppColors.logoBoxBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocStatusPill({
    required String label,
    required bool isRead,
    required bool isCurrent,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.logoBoxBackground
              : (isRead ? const Color(0xFFF0FDF4) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? AppColors.primaryGoldDark
                : (isRead ? const Color(0xFF86EFAC) : AppColors.borderSubtle),
            width: isCurrent ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isRead ? Icons.check_circle_rounded : (isCurrent ? Icons.arrow_right_alt_rounded : Icons.radio_button_unchecked),
              size: 14,
              color: isRead ? const Color(0xFF16A34A) : (isCurrent ? AppColors.primaryGoldDark : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
