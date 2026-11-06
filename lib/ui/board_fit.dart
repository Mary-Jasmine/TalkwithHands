import 'package:flutter/material.dart';

/// Keeps a classroom-screen panel inside the green board (gb.png).
///
/// The panel is anchored to the bottom of the space it is given and its
/// height is capped to the green area, so its TOP can never rise above the
/// top of the green board no matter how tall the header above it is.
/// 
/// [boardTopFraction] must be the same value passed to ClassroomPageBackground.
/// Put this in lib/ui/board_fit.dart.
class BoardFit extends StatelessWidget {
  final double boardTopFraction;
  final Widget child;

  /// Gap between the top of the green board and the panel (fraction of height).
  final double topGap;

  const BoardFit({
    super.key,
    required this.boardTopFraction,
    required this.child,
    this.topGap = 0.01,
  });

  // Green board starts roughly this far below the board image's top edge,
  // measured from the Progress screen (green top ≈ 0.375 when fraction = 0.31).
  static const double _greenTopOffset = 0.065;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height) return child; // landscape: leave as is

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final cap = size.height *
            (1 - (boardTopFraction + _greenTopOffset + topGap)) -
        safeBottom;

    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight.isFinite && c.maxHeight < cap ? c.maxHeight : cap;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(height: h, width: double.infinity, child: child),
        );
      },
    );
  }
}
