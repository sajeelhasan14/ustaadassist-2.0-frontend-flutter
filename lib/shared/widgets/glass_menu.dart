import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// One line in a [GlassMenuButton].
class GlassMenuItem {
  const GlassMenuItem(this.label, this.icon, this.onTap, {this.danger = false, this.askAgain = true});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Red, and set apart below the other items (Delete, Clear…).
  final bool danger;

  /// "Safe delete": the first tap turns the line into "Tap again to …" and only
  /// the second tap does it. Turned off where a dialog already explains the loss.
  final bool askAgain;
}

/// The "⋮" button that opens the glass menu (the chosen design: floating
/// frosted card, icons, Delete apart in red, the rest of the screen blurred
/// with the tapped row kept sharp). Used instead of Flutter's PopupMenuButton,
/// which can't blur the screen or ask twice.
class GlassMenuButton extends StatelessWidget {
  const GlassMenuButton({super.key, required this.tooltip, required this.items, this.icon = Icons.more_vert_rounded});

  final String tooltip;
  final List<GlassMenuItem> items;
  final IconData icon;

  /// The row or card this button sits in: going outwards from the button, the
  /// biggest box that is most of the screen wide but still under 40% of its
  /// height (bigger than that is the whole list, not a row). It stays sharp while
  /// the menu is open.
  Rect _rowAround(BuildContext context, Rect button) {
    final screen = MediaQuery.sizeOf(context);
    var found = button;
    RenderObject? node = context.findRenderObject();
    while (node != null) {
      if (node is RenderBox && node.hasSize) {
        if (node.size.height > screen.height * 0.4) break;
        if (node.size.width >= screen.width * 0.6) found = node.localToGlobal(Offset.zero) & node.size;
      }
      node = node.parent;
    }
    return found;
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final button = box.localToGlobal(Offset.zero) & box.size;
    // The menu closes first and hands back what was chosen; running it after the
    // menu is gone means an action can open its own dialog normally.
    final chosen = await Navigator.of(context).push(_GlassMenuRoute(button: button, row: _rowAround(context, button), items: items));
    chosen?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: AppColors.textMuted),
      onPressed: () => _open(context),
    );
  }
}

/// A route is one layer on the navigator's stack, like a page or a dialog.
/// PopupRoute = a see-through layer that closes when you tap outside it.
class _GlassMenuRoute extends PopupRoute<VoidCallback> {
  _GlassMenuRoute({required this.button, required this.row, required this.items});

  final Rect button;
  final Rect row;
  final List<GlassMenuItem> items;

  @override
  Color? get barrierColor => null; // we paint our own blur instead

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const width = 248.0;
    final height = items.length * 52.0 + (items.any((item) => item.danger) ? 13 : 0) + 12;
    // Below the button if it fits, otherwise above it. Right edges line up.
    final below = button.bottom + 4 + height <= screen.height - padding.bottom - 8;
    final top = below ? button.bottom + 4 : button.top - 4 - height;
    final left = (button.right - width).clamp(8.0, screen.width - width - 8);

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: Stack(
        children: [
          // "Focus": blur and dim everything except the row the menu belongs to.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: ClipPath(
                clipper: _AllBut(row),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ColoredBox(color: AppColors.isLight ? const Color(0x1F0E1412) : const Color(0x66000000)),
                ),
              ),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              alignment: below ? Alignment.topRight : Alignment.bottomRight,
              child: _MenuCard(items: items),
            ),
          ),
        ],
      ),
    );
  }
}

/// A clip shape covering the whole screen with one rounded hole: the row.
class _AllBut extends CustomClipper<Path> {
  const _AllBut(this.hole);

  final Rect hole;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd // the second shape cuts a hole in the first
    ..addRect(Offset.zero & size)
    ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(18)));

  @override
  bool shouldReclip(_AllBut old) => old.hole != hole;
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({required this.items});

  final List<GlassMenuItem> items;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  GlassMenuItem? _armed; // a danger item tapped once, waiting for the second tap

  void _tap(GlassMenuItem item) {
    if (item.danger && item.askAgain && _armed != item) {
      setState(() => _armed = item);
      return;
    }
    Navigator.of(context).pop(item.onTap);
  }

  @override
  Widget build(BuildContext context) {
    final normal = widget.items.where((item) => !item.danger).toList();
    final danger = widget.items.where((item) => item.danger).toList();
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.dock,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in normal) _line(item),
                if (normal.isNotEmpty && danger.isNotEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(color: AppColors.line, height: 1)),
                for (final item in danger) _line(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(GlassMenuItem item) {
    final armed = _armed == item;
    final colour = item.danger ? (armed ? AppColors.onDanger : AppColors.dangerText) : AppColors.text;
    final verb = item.label.split(' ').first.toLowerCase(); // "Delete section" -> "delete"
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _tap(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: armed ? AppColors.danger : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(armed ? Icons.warning_amber_rounded : item.icon, size: 20, color: item.danger ? colour : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(armed ? 'Tap again to $verb' : item.label, style: AppText.rowTitle.copyWith(color: colour), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
