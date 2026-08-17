import 'package:flutter/material.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

enum RiskBadgeSize { small, medium, large }

class RiskBadge extends StatelessWidget {

  final String flag;

  final RiskBadgeSize size;

  final bool showLabel;

  final String? customLabel;

  const RiskBadge({
    super.key,
    required this.flag,
    this.size       = RiskBadgeSize.medium,
    this.showLabel  = true,
    this.customLabel,
  });

  factory RiskBadge.fromScore({
    required int     score,
    RiskBadgeSize    size      = RiskBadgeSize.medium,
    bool             showLabel = true,
  }) {
    final String flag;
    if (score >= 4) {
      flag = 'ALLERGEN';
    } else if (score == 3) flag = 'CAUTION';
    else                 flag = 'SAFE';

    return RiskBadge(
      flag:      flag,
      size:      size,
      showLabel: showLabel,
    );
  }

  Color get _bgColor    => AppColors.riskBgColor(flag);
  Color get _textColor  => AppColors.riskTextColor(flag);
  Color get _mainColor  => AppColors.riskColor(flag);

  IconData get _icon {
    switch (flag.toUpperCase()) {
      case 'SAFE':
        return Icons.check_circle_rounded;
      case 'CAUTION':
        return Icons.warning_amber_rounded;
      case 'ALLERGEN':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // ─────────────────────────────────────────────────────
  // LABEL TEXT
  // ─────────────────────────────────────────────────────
  String get _label {
    if (customLabel != null) return customLabel!;
    switch (flag.toUpperCase()) {
      case 'SAFE':     return 'Safe';
      case 'CAUTION':  return 'Caution';
      case 'ALLERGEN': return 'Allergen';
      default:         return flag;
    }
  }

  // ─────────────────────────────────────────────────────
  // SIZE VALUES
  // ─────────────────────────────────────────────────────
  double get _iconSize {
    switch (size) {
      case RiskBadgeSize.small:  return 11;
      case RiskBadgeSize.medium: return 13;
      case RiskBadgeSize.large:  return 18;
    }
  }

  double get _fontSize {
    switch (size) {
      case RiskBadgeSize.small:  return 10;
      case RiskBadgeSize.medium: return 12;
      case RiskBadgeSize.large:  return 14;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case RiskBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 7, vertical: 3);
      case RiskBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
      case RiskBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 7);
    }
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: _padding,
      decoration: BoxDecoration(
        color:        _bgColor,
        borderRadius: BorderRadius.circular(20), // fully rounded pill
        border: Border.all(
          color: _mainColor.withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // shrink to content width
        children: [

          // ── Icon ───────────────────────────────────────
          Icon(
            _icon,
            size:  _iconSize,
            color: _mainColor,
          ),

          // ── Label ──────────────────────────────────────
          if (showLabel) ...[
            SizedBox(width: size == RiskBadgeSize.small ? 3 : 5),
            Text(
              _label,
              style: TextStyle(
                fontSize:      _fontSize,
                fontWeight:    FontWeight.w700,
                color:         _textColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────
// RISK BADGE ROW
// Shows all 3 badges in a row — used in legend/key displays
//
// HOW TO USE:
//   RiskBadgeRow()                    // all 3 badges
//   RiskBadgeRow(size: RiskBadgeSize.small)  // small version
// ─────────────────────────────────────────────────────────
class RiskBadgeRow extends StatelessWidget {
  final RiskBadgeSize size;

  const RiskBadgeRow({
    super.key,
    this.size = RiskBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RiskBadge(flag: 'SAFE',     size: size),
        const SizedBox(width: 6),
        RiskBadge(flag: 'CAUTION',  size: size),
        const SizedBox(width: 6),
        RiskBadge(flag: 'ALLERGEN', size: size),
      ],
    );
  }
}