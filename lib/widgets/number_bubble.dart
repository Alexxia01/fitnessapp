import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A number input styled as its own small raised "bubble" — a filled,
/// shadowed surface with a border that brightens on focus — instead of a
/// plain flat text field. Shared by the workout log's weight/reps fields
/// and the nutrition log's Amount field, so both look identical rather
/// than two hand-tuned copies drifting apart.
///
/// Bypasses the app-wide InputDecorationTheme entirely (all three of
/// border/enabledBorder/focusedBorder set to InputBorder.none) so this
/// shadow/border combo is the only thing drawing its edges — the global
/// theme's own OutlineInputBorder otherwise wins and draws its own
/// (purple, pill-shaped) border on top of this one.
///
/// Reads as "raised" specifically because it's *darker* than whatever
/// it sits on — `colors.background` is darker than the `colors.surface`
/// card this is normally placed inside. Wrap it in a `colors.surface`
/// container first if the immediate parent isn't already one (e.g. a
/// bottom sheet whose own root is `colors.background`).
class NumberBubble extends StatefulWidget {
  final double width;
  final double height;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final String? suffixText;

  const NumberBubble({
    super.key,
    required this.width,
    this.height = 48,
    required this.controller,
    required this.keyboardType,
    this.onChanged,
    this.suffixText,
  });

  @override
  State<NumberBubble> createState() => _NumberBubbleState();
}

class _NumberBubbleState extends State<NumberBubble> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _focused ? colors.lilacTint : colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? colors.purpleDeep : colors.border,
          width: _focused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          if (isDark)
            BoxShadow(
              color: colors.ink.withOpacity(0.05),
              blurRadius: 0,
              spreadRadius: -1,
              offset: const Offset(0, -1),
            ),
        ],
      ),
      // The suffix (e.g. " g") used to go through InputDecoration's own
      // suffixText, but that pins it to the far right edge of the field —
      // with a fixed-width box and centered input text, that left a gap
      // of empty flexible space between the number and the unit. Instead
      // the number and unit are laid out side by side as their own row,
      // centered together as one unit, so the unit sits right up against
      // the digits no matter how wide the bubble is.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IntrinsicWidth(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
              textAlign: TextAlign.center,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: colors.ink,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (widget.suffixText != null)
            Text(
              widget.suffixText!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.mutedText,
              ),
            ),
        ],
      ),
    );
  }
}
