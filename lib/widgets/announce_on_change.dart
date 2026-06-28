import 'package:flutter/widgets.dart';

/// Wraps [builder] and tells it to flag a live region for exactly one frame
/// after [value] actually changes, then resets — so a screen reader
/// announces real transitions once and ignores unrelated rebuilds.
class AnnounceOnChange extends StatefulWidget {
  final String value;
  final Widget Function(BuildContext context, bool liveRegion) builder;

  const AnnounceOnChange({
    super.key,
    required this.value,
    required this.builder,
  });

  @override
  State<AnnounceOnChange> createState() => _AnnounceOnChangeState();
}

class _AnnounceOnChangeState extends State<AnnounceOnChange> {
  bool _liveRegion = false;

  @override
  void didUpdateWidget(AnnounceOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_liveRegion) {
      _liveRegion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _liveRegion = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _liveRegion);
}
