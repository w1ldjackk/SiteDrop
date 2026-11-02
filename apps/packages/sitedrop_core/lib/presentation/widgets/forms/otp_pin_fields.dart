// lib/presentation/widgets/forms/otp_pin_fields.dart
// Modern, responsive OTP pin inputs with auto-advance, paste + backspace
// handling, SMS autofill support and error/success states.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sitedrop_core/app/theme/colors.dart';

/// Responsive OTP boxes that scale down gracefully on narrow screens.
///
/// Pass [onCompleted] to auto-verify as soon as the last digit is entered —
/// screens should wire that to their verify handler and guard re-entry with
/// their own `_isLoading` flag. [hasError] tints the boxes red and plays a
/// short shake animation; the parent clears it on the next change.
class OtpPinFields extends StatefulWidget {
  const OtpPinFields({
    super.key,
    required this.controllers,
    this.focusNodes,
    this.enabled = true,
    this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.hasError = false,
    this.autoFocusFirst = false,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode>? focusNodes;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final int length;
  final bool hasError;
  final bool autoFocusFirst;

  @override
  State<OtpPinFields> createState() => _OtpPinFieldsState();
}

class _OtpPinFieldsState extends State<OtpPinFields>
    with SingleTickerProviderStateMixin {
  late final List<FocusNode> _ownedFocusNodes;
  late final List<FocusNode> _focusNodes;
  bool _ownsFocusNodes = false;
  late final AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.focusNodes != null &&
        widget.focusNodes!.length >= widget.length) {
      _focusNodes = widget.focusNodes!;
      _ownedFocusNodes = const [];
      _ownsFocusNodes = false;
    } else {
      _ownedFocusNodes = List.generate(widget.length, (_) => FocusNode());
      _focusNodes = _ownedFocusNodes;
      _ownsFocusNodes = true;
    }
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    if (widget.autoFocusFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant OtpPinFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    if (_ownsFocusNodes) {
      for (final node in _ownedFocusNodes) {
        node.dispose();
      }
    }
    super.dispose();
  }

  String get _code =>
      widget.controllers.take(widget.length).map((c) => c.text).join();

  void _notify() {
    final code = _code;
    widget.onChanged?.call(code);
    if (code.length == widget.length &&
        !code.contains(RegExp(r'\D')) &&
        code.trim().length == widget.length) {
      // Defer so the last box paints before the screen shows loading.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Re-read in case the user edited during the frame.
        final fresh = _code;
        if (fresh.length == widget.length) widget.onCompleted?.call(fresh);
      });
    }
  }

  void _fillFromPaste(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.length; i++) {
      widget.controllers[i].value = TextEditingValue(
        text: i < digits.length ? digits[i] : '',
        selection: const TextSelection.collapsed(offset: 1),
      );
    }
    if (digits.length >= widget.length) {
      _focusNodes[widget.length - 1].requestFocus();
    } else if (digits.isNotEmpty) {
      _focusNodes[digits.length.clamp(0, widget.length - 1)].requestFocus();
    }
    _notify();
  }

  void _onChanged(int index, String value) {
    if (!widget.enabled) return;
    // Paste of the full code (or SMS autofill) into any box.
    if (value.length > 1) {
      _fillFromPaste(value);
      return;
    }
    if (value.isNotEmpty) {
      // Keep only the last typed digit.
      final digit = value.characters.last;
      if (widget.controllers[index].text != digit) {
        widget.controllers[index].value = TextEditingValue(
          text: digit,
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _notify();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isBackspace =
        event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete;
    if (!isBackspace) return KeyEventResult.ignored;
    // Slot already empty -> jump back and clear the previous one.
    if (widget.controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      widget.controllers[index - 1].clear();
      _notify();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasError = widget.hasError;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;
        final compact = available < 320;
        final gap = compact ? 6.0 : 8.0;
        final totalGaps = gap * (widget.length - 1);
        final boxWidth =
            ((available - totalGaps) / widget.length).clamp(40.0, 56.0);
        final boxHeight = compact ? 52.0 : 60.0;
        final fontSize = compact ? 20.0 : 24.0;
        final radius = BorderRadius.circular(16);

        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = hasError
                ? _shakeAnimation.value *
                      (_shakeController.value < 0.5 ? 1 : -1) *
                      (1 - _shakeController.value)
                : 0.0;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: AutofillGroup(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                final isLast = index == widget.length - 1;
                final focused = _focusNodes[index].hasFocus;
                return Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : gap),
                  child: Focus(
                    onKeyEvent: (_, event) => _onKey(index, event),
                    child: SizedBox(
                      width: boxWidth,
                      height: boxHeight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controllers[index],
                        builder: (_, value, _) {
                          final isFilled = value.text.isNotEmpty;
                          final borderColor = hasError
                              ? AppColors.error
                              : focused || isFilled
                                  ? AppColors.primary
                                  : p.inputBorder;
                          final fillColor = hasError
                              ? AppColors.error.withValues(alpha: 0.06)
                              : isFilled
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : p.inputFill;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: radius,
                              border: Border.all(
                                color: borderColor,
                                width: focused || isFilled || hasError
                                    ? 2
                                    : 1.5,
                              ),
                              boxShadow: focused && !hasError
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: widget.controllers[index],
                              focusNode: _focusNodes[index],
                              enabled: widget.enabled,
                              textAlign: TextAlign.center,
                              textAlignVertical: TextAlignVertical.center,
                              keyboardType: TextInputType.number,
                              textInputAction: isLast
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              maxLength: 1,
                              autofillHints: const [
                                AutofillHints.oneTimeCode,
                              ],
                              enableInteractiveSelection: true,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: hasError
                                    ? AppColors.error
                                    : p.textPrimary,
                                letterSpacing: 0,
                              ),
                              cursorColor: AppColors.primary,
                              cursorWidth: 2,
                              cursorRadius: const Radius.circular(2),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                              decoration: const InputDecoration(
                                counterText: '',
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) =>
                                  _onChanged(index, value),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
