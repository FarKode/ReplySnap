import 'package:flutter/material.dart';

class AppTheme {
  // Premium Light Neomorphism Color Palette (Inspired by modern high-end UIs)
  static const Color background = Color(0xFFE3EDF7); // Soft light blue-grey base
  static const Color surface = Color(0xFFE3EDF7);    // Matches background for seamless 3D mold
  static const Color accent = Color(0xFF8B5CF6);     // Vibrant violet accent
  static const Color text = Color(0xFF31394A);       // Deep slate-navy for readability
  static const Color textMuted = Color(0xFF7A869A);  // Muted slate-grey

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        background: background,
        surface: surface,
        primary: accent,
        onBackground: text,
        onSurface: text,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 20),
        bodyLarge: TextStyle(color: text, fontSize: 16),
        bodyMedium: TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }

  // Premium Light Neomorphic Card Decoration
  static BoxDecoration neomorphicCard({
    double radius = 24,
    bool isPressed = false,
    Color? color,
  }) {
    final baseColor = color ?? surface;

    Color adjustColor(Color c, double factor) {
      final double r = c.red * (1.0 + factor);
      final double g = c.green * (1.0 + factor);
      final double b = c.blue * (1.0 + factor);
      return Color.fromARGB(
        c.alpha,
        r.clamp(0.0, 255.0).round(),
        g.clamp(0.0, 255.0).round(),
        b.clamp(0.0, 255.0).round(),
      );
    }

    // Curvature gradient
    final Color startColor = isPressed ? adjustColor(baseColor, -0.08) : adjustColor(baseColor, 0.02);
    final Color endColor = isPressed ? adjustColor(baseColor, 0.02) : adjustColor(baseColor, -0.04);

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [startColor, endColor],
      ),
      boxShadow: isPressed
          ? [
              // Inset debossed shadow
              BoxShadow(
                color: const Color(0xFFA3B1C6).withOpacity(0.8),
                offset: const Offset(3, 3),
                blurRadius: 5,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFFFFFFFF).withOpacity(0.9),
                offset: const Offset(-3, -3),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ]
          : [
              // Extruded 3D soft double shadows (matching reference image)
              BoxShadow(
                color: const Color(0xFFA3B1C6).withOpacity(0.65), // Soft dark shadow bottom-right
                offset: const Offset(6, 6),
                blurRadius: 14,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFFFFFFFF).withOpacity(0.95), // Bright white highlight top-left
                offset: const Offset(-6, -6),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
    );
  }

  // Neomorphic Inset/Readable card background (for text areas)
  static BoxDecoration neomorphicReadable({double radius = 24}) {
    return BoxDecoration(
      color: const Color(0xFFDCE6F1), // Soft inset base
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFEFF5FC), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFA3B1C6).withOpacity(0.4),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: 0.5,
        ),
      ],
    );
  }
}

// Premium 3D Neomorphic Button (Supports Extruded & Inset states)
class NeomorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final bool isSelected;
  final Color? color;

  const NeomorphicButton({
    Key? key,
    required this.child,
    required this.onTap,
    this.radius = 24,
    this.isSelected = false,
    this.color,
  }) : super(key: key);

  @override
  State<NeomorphicButton> createState() => _NeomorphicButtonState();
}

class _NeomorphicButtonState extends State<NeomorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool activeState = _isPressed || widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: AppTheme.neomorphicCard(
          radius: widget.radius,
          isPressed: activeState,
          color: widget.color,
        ).copyWith(
          border: Border.all(
            color: activeState
                ? (widget.color == null ? AppTheme.accent.withOpacity(0.8) : Colors.white60)
                : Colors.transparent,
            width: activeState ? 1.5 : 0.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: widget.child,
      ),
    );
  }
}
