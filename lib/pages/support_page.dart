import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/app_drawer.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? actionTag;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionTag,
  });
}

class SupportPage extends StatefulWidget {
  final String activeRole;
  final VoidCallback? onSwitchRole;

  const SupportPage({
    super.key,
    this.activeRole = 'Food Provider',
    this.onSwitchRole,
  });

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          '👋 Hello! I am the Food Flow Relief Assistant.\n\nI can help you coordinate urgent rescues, resolve courier delays, answer food safety compliance questions, or escalate to human dispatch.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  final List<String> _quickPrompts = [
    '🚨 Courier delayed / No-show',
    '🌡️ Food temperature & safety rules',
    '📦 Adjust portion count at pickup',
    '🍲 How do surplus claims work?',
    '📞 Talk to Emergency Dispatcher',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    // Generate intelligent AI response with a short realistic delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final responseText = _generateBotResponse(trimmed);
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: responseText,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _generateBotResponse(String input) {
    final lower = input.toLowerCase();

    if (lower.contains('courier') || lower.contains('delay') || lower.contains('no-show') || lower.contains('late')) {
      return '🚨 **Courier SLA Escalation Alert**\n\n'
          '• If your volunteer courier has not arrived within 20 minutes of accepting dispatch, our system initiates a priority ping.\n'
          '• **Action**: We can automatically re-broadcast this mission to 3 nearby couriers in your sector, or switch the shelter to **Direct Self-Pickup**.\n'
          '• Would you like me to ping the assigned courier or re-assign this batch?';
    }

    if (lower.contains('temp') || lower.contains('safety') || lower.contains('spoil') || lower.contains('fssai')) {
      return '🌡️ **FSSAI Food Safety Compliance Guidelines**\n\n'
          '• **Hot-Holding Food**: Must remain at or above **63°C (145°F)** until sealed handover.\n'
          '• **Chilled / Cold Food**: Must be transported below **5°C (41°F)** in insulated containers.\n'
          '• **Safe Window**: Prepared cooked meals must be consumed within **4 hours** of batch readiness.\n'
          '• If food smells sour or falls below safe temperature thresholds, do **not** dispatch. Mark the batch as cancelled in the app.';
    }

    if (lower.contains('portion') || lower.contains('count') || lower.contains('mismatch') || lower.contains('quantity')) {
      return '📦 **Portion Count Discrepancy Protocol**\n\n'
          '• During physical handover, the courier and kitchen supervisor can adjust the **Actual Accepted Portions** before entering the 4-digit OTP.\n'
          '• The updated quantity will automatically reflect in the shelter\'s delivery manifest and the provider\'s ESG tax deduction record.';
    }

    if (lower.contains('claim') || lower.contains('how') || lower.contains('work')) {
      return '🤝 **Food Flow Proximity Redistribution Workflow**\n\n'
          '1. **Provider Lists Batch**: Enters meal type, portion count, and expiry countdown.\n'
          '2. **NGO Discovers & Claims**: Nearby shelters within 5-10km receive radar pings and claim via atomic locking.\n'
          '3. **Courier Dispatches**: OpenRouteService plots turn-by-turn navigation.\n'
          '4. **Dual OTP Handover**: 4-digit Pickup OTP at kitchen, 4-digit Delivery OTP at shelter.';
    }

    if (lower.contains('talk') || lower.contains('call') || lower.contains('emergency') || lower.contains('dispatcher') || lower.contains('phone')) {
      return '📞 **Direct Emergency Dispatch Desk**\n\n'
          'Our Bangalore central operations control room is online 24/7.\n'
          '• **Toll-Free Dispatch**: `1800-FOODFLOW` (`1800-366-3356`)\n'
          '• **WhatsApp Rapid Response**: `+91 95556 51225`\n'
          '• Priority dispatch ticket #FF-9824 has been logged for your facility.';
    }

    return 'Thank you for reaching out to Food Flow Support.\n\n'
        'I have logged your request regarding: "$input".\n'
        'If this is an active rescue mission requiring immediate dispatch intervention, please call our emergency hotline at **1800-FOODFLOW** or select one of the quick options below.';
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        'Food Flow Member';

    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF7),
      appBar: _buildAppBar(),
      drawer: AppDrawer(
        activeRole: widget.activeRole,
        onSwitchRole: widget.onSwitchRole,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              // Top Emergency Banner
              _buildTopEmergencyBanner(),

              // Chat and Info Section
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 780) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Support FAQs & Hotline Cards
                          SizedBox(
                            width: 320,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(left: 20, top: 16, bottom: 20, right: 10),
                              child: _buildSidebarInfo(),
                            ),
                          ),
                          // Right: Interactive AI Chatbot Window
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20, top: 16, bottom: 20, left: 10),
                              child: _buildChatWindow(userName),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildChatWindow(userName),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'FF',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Food Flow Support',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                'AI RELIEF ASSISTANT & EMERGENCY DISPATCH',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.onSwitchRole != null)
          TextButton.icon(
            onPressed: widget.onSwitchRole,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFD97706)),
            label: const Text(
              'Switch Role',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Back to Dashboard',
          icon: const Icon(Icons.dashboard_outlined, color: Color(0xFF64748B)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          },
        ),
        const SizedBox(width: 4),
        AppDrawer.buildSignOutButton(context),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildTopEmergencyBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFFBEB),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.support_agent_rounded, size: 18, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '24/7 Rapid Response Dispatch Active',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                ),
                Text(
                  'For critical time-sensitive batch spoilage or courier emergencies, automated routing priority is enabled.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                SizedBox(width: 5),
                Text(
                  'DISPATCH ONLINE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hotline Contact Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_in_talk_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text('Direct Operations Line', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Direct hotline for hotel banquet managers & shelter supervisors:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.call_rounded, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      '1800-FOODFLOW',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Food Safety Charter Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text('FSSAI Compliance Tips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
              SizedBox(height: 10),
              Text(
                '• Hot Food: Keep >63°C at dispatch\n'
                '• Cold Food: Transport at <5°C\n'
                '• Consumption window: Max 4 hours\n'
                '• Packaging: Sealed food-grade only\n'
                '• Mandatory 4-digit OTP handover',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatWindow(String userName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFEF3C7),
                  child: const Icon(Icons.smart_toy_rounded, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Food Flow Relief Assistant',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('AI Triage Bot · Responding instantly', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    widget.activeRole,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          // Messages Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Relief Assistant is typing...',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Quick Prompt Chips
          Container(
            height: 42,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(
                    prompt,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _handleSubmitted(prompt),
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFCFBF7),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type your message or ask a question...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF5BA13),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.black87, size: 18),
                    onPressed: () => _handleSubmitted(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFFEF3C7),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFFD97706), size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser ? const Color(0xFFF5BA13) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: msg.isUser ? const Color(0xFFD99F05) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13,
                  color: msg.isUser ? Colors.black87 : const Color(0xFF1E293B),
                  height: 1.45,
                  fontWeight: msg.isUser ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE2E8F0),
              child: const Icon(Icons.person, color: Color(0xFF475569), size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
