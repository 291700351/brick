import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/state.dart';

abstract class StatelessLayout extends StatelessWidget {
  final ViewState _state;
  final Duration? _transitionDuration;
  final Curve? _transitionCurve;
  final AnimatedSwitcherTransitionBuilder? _transitionBuilder;

  final VoidCallback? onRetry;

  const StatelessLayout({
    super.key,
    required this._state,
    this._transitionDuration,
    this._transitionCurve,
    this._transitionBuilder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = _buildChild(context, _state);
    final dur = _transitionDuration ?? const Duration(milliseconds: 180);
    final curve = _transitionCurve ?? Curves.easeInOut;
    return AnimatedSwitcher(
      duration: dur,
      switchInCurve: curve,
      switchOutCurve: curve,
      key: ValueKey(_state),
      transitionBuilder:
          _transitionBuilder ??
          (Widget child, Animation<double> animation) {
            // 默认：淡入淡出
            return FadeTransition(opacity: animation, child: child);
          },
      child: child,
    );
  }

  Widget _buildChild(BuildContext context, ViewState state) {
    return switch (state) {
      Loading(tip: final tip, progress: final progress) =>
        onBuildLoading(context, tip, progress) ?? const SizedBox.shrink(),
      Success() => onBuildSuccess(context),
      Empty(e: final e) => onBuildEmpty(context, e) ?? const SizedBox.shrink(),
      Error(e: final e) => onBuildError(context, e) ?? const SizedBox.shrink(),
    };
  }

  //==Desc:=================================================================
  Widget? onBuildLoading(
    BuildContext context, [
    String? tip,
    double? progress,
  ]) => null;

  Widget? onBuildEmpty(BuildContext context, [AppException? e]) => null;

  Widget? onBuildError(BuildContext context, [AppException? e]) => null;

  Widget onBuildSuccess(BuildContext context);
}
