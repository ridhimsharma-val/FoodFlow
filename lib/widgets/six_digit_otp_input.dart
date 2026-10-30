import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpCodeInput extends StatefulWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final Color activeBorderColor;
  final Color inactiveBorderColor;
  final Color fillColor;

  const OtpCodeInput({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.onCompleted,
    this.onChanged,
    this.activeBorderColor = const Color(0xFFF5BA13),
    this.inactiveBorderColor = const Color(0xFFE2E8F0),
    this.fillColor = Colors.white,
  }) : assert(controllers.length == focusNodes.length,
            'controllers and focusNodes must have the exact same length');

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

// Backwards compatibility aliases
typedef SixDigitOtpInput = OtpCodeInput;
typedef EightDigitOtpInput = OtpCodeInput;

class _OtpCodeInputState extends State<OtpCodeInput> {
  int get totalDigits => widget.controllers.length;

  void _handleTextChange(int index, String value) {
    // 1. Check if user pasted a multi-digit code (e.g., 8 digits at once)
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 1) {
      for (int i = 0; i < totalDigits; i++) {
        if (i < digits.length) {
          widget.controllers[i].text = digits[i];
        } else {
          widget.controllers[i].clear();
        }
      }
      final filledLength = digits.length.clamp(0, totalDigits);
      if (filledLength == totalDigits) {
        widget.focusNodes[totalDigits - 1].requestFocus();
        final fullOtp = widget.controllers.map((c) => c.text.trim()).join();
        widget.onChanged?.call(fullOtp);
        widget.onCompleted?.call(fullOtp);
      } else {
        widget.focusNodes[filledLength].requestFocus();
        final currentOtp = widget.controllers.map((c) => c.text.trim()).join();
        widget.onChanged?.call(currentOtp);
      }
      return;
    }

    // 2. Single digit entered
    if (value.isNotEmpty) {
      // Keep only the last typed character if multiple entered
      if (value.length > 1) {
        widget.controllers[index].text = value.substring(value.length - 1);
      }
      if (index < totalDigits - 1) {
        widget.focusNodes[index + 1].requestFocus();
      }
    }

    final currentOtp = widget.controllers.map((c) => c.text.trim()).join();
    widget.onChanged?.call(currentOtp);

    if (currentOtp.length == totalDigits) {
      widget.onCompleted?.call(currentOtp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Adjust gap based on total digits so 8 boxes fit nicely
        final double gap = totalDigits > 6 ? 6.0 : 8.0;
        final availableForBoxes = totalWidth - (gap * (totalDigits - 1));
        final boxWidth = (availableForBoxes / totalDigits).clamp(32.0, 52.0);
        final boxHeight = (boxWidth * 1.22).clamp(44.0, 58.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalDigits, (i) {
            return SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    if (widget.controllers[i].text.isEmpty && i > 0) {
                      widget.controllers[i - 1].clear();
                      widget.focusNodes[i - 1].requestFocus();
                      final currentOtp = widget.controllers
                          .map((c) => c.text.trim())
                          .join();
                      widget.onChanged?.call(currentOtp);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: widget.controllers[i],
                  focusNode: widget.focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: totalDigits, // allows pasting full OTP into any box
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    fontSize: (boxWidth * 0.46).clamp(16.0, 22.0),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF18181B),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: widget.fillColor,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: widget.inactiveBorderColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: widget.inactiveBorderColor,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: widget.activeBorderColor,
                        width: 2.2,
                      ),
                    ),
                  ),
                  onChanged: (v) => _handleTextChange(i, v),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
