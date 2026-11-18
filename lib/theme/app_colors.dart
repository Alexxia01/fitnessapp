import 'package:flutter/material.dart';

/// Compound's color palette, theme-aware.
///
/// Reach for these through `context.colors.xxx` (never a raw hex, never a
/// literal `Colors.white` for anything that should read as a card/sheet
/// surface) so every screen automatically follows whichever theme — light
/// or dark — is active. Build a new screen on top of this and dark mode
/// already works for it, for free.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // Teal — the brand color. Hero/header gradients, primary buttons,
  // anything that represents an action.
  final Color tealVivid;
  final Color tealDeep;

  // Lilac — a soft accent for "this is something you set yourself"
  // (a target rep range, a rep count) — not Compound telling you anything.
  final Color lilacBackground;
  final Color lilacText;
  final Color lilacTint;

  // Deep purple — a stronger accent for "this is a reflection on your
  // history" (last time's numbers, a failure-set note).
  final Color purpleDeep;

  // Neutral tones shared by every screen.
  final Color background; // the screen's base background
  final Color surface; // card/sheet backgrounds — was hardcoded Colors.white
  final Color ink; // primary text
  final Color mutedText;
  final Color border;

  const AppColors({
    required this.tealVivid,
    required this.tealDeep,
    required this.lilacBackground,
    required this.lilacText,
    required this.lilacTint,
    required this.purpleDeep,
    required this.background,
    required this.surface,
    required this.ink,
    required this.mutedText,
    required this.border,
  });

  static const light = AppColors(
    tealVivid: Color(0xFF14C9AE),
    tealDeep: Color(0xFF0B6E63),
    lilacBackground: Color(0xFFE7D6FA),
    lilacText: Color(0xFF5B3A8C),
    lilacTint: Color(0xFFF3EAFB),
    purpleDeep: Color(0xFF7A4FC9),
    background: Color(0xFFF6FAF9),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF15231F),
    mutedText: Color(0xFF5F7470),
    border: Color(0xFFDCEAE6),
  );

  // purpleDeep is tuned a shade darker than a pure accent purple would be,
  // specifically because this one doubles as a *fill* behind white
  // text/icons (selected chips, the "last time" pill) — a lighter purple
  // wouldn't have enough contrast there.
  //
  // Unlike the light palette, the neutrals here (background/surface/
  // border/ink/mutedText) are deliberately NOT teal-tinted. Dark mode with
  // every neutral pulled toward the brand hue reads as murky — your eye
  // can't tell "chrome" from "accent" apart, and it dulls the actual brand
  // teal since it's no longer contrasting against anything. Cool, genuinely
  // neutral grays let teal/purple be the only things with color, so they
  // pop instead of blending in.
  static const dark = AppColors(
    tealVivid: Color(0xFF2FE6C4),
    tealDeep: Color(0xFF12A190),
    // Pushed more saturated than you'd expect from a "fill" color — low
    // saturation here read as muddy next to the rest of the neon palette.
    // This is a fill meant to glow, not recede.
    lilacBackground: Color(0xFF4A2F91),
    lilacText: Color(0xFFE4D6FF),
    lilacTint: Color(0xFF241B35),
    purpleDeep: Color(0xFF8F5FE8),
    background: Color(0xFF0B0D11),
    // A deliberate dark-teal tint, not flat gray — gives cards their own
    // identity instead of reading as "a slightly lighter smear of the
    // background." Paired with dropping the card border entirely (see
    // main_screen.dart / workout_log_screen.dart): separation now comes
    // from this color actually standing apart, not an outline.
    surface: Color(0xFF1B332E),
    ink: Color(0xFFF1F3F6),
    mutedText: Color(0xFF9AA3B0),
    border: Color(0xFF2B303B),
  );

  @override
  AppColors copyWith({
    Color? tealVivid,
    Color? tealDeep,
    Color? lilacBackground,
    Color? lilacText,
    Color? lilacTint,
    Color? purpleDeep,
    Color? background,
    Color? surface,
    Color? ink,
    Color? mutedText,
    Color? border,
  }) {
    return AppColors(
      tealVivid: tealVivid ?? this.tealVivid,
      tealDeep: tealDeep ?? this.tealDeep,
      lilacBackground: lilacBackground ?? this.lilacBackground,
      lilacText: lilacText ?? this.lilacText,
      lilacTint: lilacTint ?? this.lilacTint,
      purpleDeep: purpleDeep ?? this.purpleDeep,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      tealVivid: Color.lerp(tealVivid, other.tealVivid, t)!,
      tealDeep: Color.lerp(tealDeep, other.tealDeep, t)!,
      lilacBackground: Color.lerp(lilacBackground, other.lilacBackground, t)!,
      lilacText: Color.lerp(lilacText, other.lilacText, t)!,
      lilacTint: Color.lerp(lilacTint, other.lilacTint, t)!,
      purpleDeep: Color.lerp(purpleDeep, other.purpleDeep, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// Shorthand so screens can write `context.colors.tealVivid` instead of
/// `Theme.of(context).extension<AppColors>()!.tealVivid`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
