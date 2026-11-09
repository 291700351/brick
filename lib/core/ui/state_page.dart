import 'package:flutter/cupertino.dart';

abstract class StatePage extends StatefulWidget {
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  final Duration? transitionDuration;
  final Curve? transitionCurve;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  const StatePage({
    super.key,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.transitionDuration,
    this.transitionCurve,
    this.transitionBuilder,
  });
}
