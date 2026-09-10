// lib/widgets/aegis_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// The Aegis brand mark — shield icon with subtle pulse + wordmark.
class AegisLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const AegisLogo({super.key, this.size = 80, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                AppColors.accent.withOpacity(0.18),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.shield_outlined,
              size: size * 0.65,
              color: AppColors.accent,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 1.0,
                  end: 1.06,
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 14),
          Text(
            'AEGIS',
            style: GoogleFonts.inter(
              fontSize: size * 0.30,
              fontWeight: FontWeight.w800,
              letterSpacing: size * 0.08,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SCAM SHIELD',
            style: GoogleFonts.jetBrainsMono(
              fontSize: size * 0.12,
              fontWeight: FontWeight.w500,
              letterSpacing: size * 0.05,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small "• SECURED" style status chip — the hacker-vibe accent.
class StatusPill extends StatelessWidget {
  final String label;
  final Color dotColor;
  const StatusPill({super.key, required this.label, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 900.ms),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Accent-gradient primary CTA. Large tap target, glow.
class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentDim],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.bgDeep, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bgDeep,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ghost button — for secondary actions like "start over".
class GhostButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const GhostButton({super.key, required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Risk verdict block — big colored badge + verdict text.
class RiskVerdictCard extends StatelessWidget {
  final String riskLevel;
  final String verdictText;
  final String? matchedCategory;
  const RiskVerdictCard({
    super.key,
    required this.riskLevel,
    required this.verdictText,
    this.matchedCategory,
  });

  IconData get _icon {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.error_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(riskLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.45), width: 2),
          ),
          child: Column(
            children: [
              Icon(_icon, color: color, size: 52),
              const SizedBox(height: 10),
              Text(
                '${riskLevel.toUpperCase()} RISK',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 2,
                ),
              ),
              if (matchedCategory != null &&
                  matchedCategory!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  matchedCategory!.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ],
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            verdictText,
            style: GoogleFonts.inter(
              fontSize: 17,
              height: 1.55,
              color: AppColors.textPrimary,
            ),
          ),
        ).animate(delay: 250.ms).fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
      ],
    );
  }
}

/// Subtle grid background — "monitoring dashboard" without being noisy.
class GridBackground extends StatelessWidget {
  final Widget child;
  const GridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.18)
      ..strokeWidth = 0.5;
    const gap = 40.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}