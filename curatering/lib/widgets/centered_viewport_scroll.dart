import 'package:flutter/material.dart';

/// Vertically centers [child] when it is shorter than the viewport; scrolls when
/// content is taller. Use under a fixed-height parent (e.g. [Expanded]).
class CenteredViewportScroll extends StatelessWidget {
  const CenteredViewportScroll({
    super.key,
    required this.child,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: crossAxisAlignment,
              children: [child],
            ),
          ),
        );
      },
    );
  }
}
