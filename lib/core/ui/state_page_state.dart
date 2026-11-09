import 'package:flutter/material.dart';
import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/state.dart';
import 'package:brick/core/ui/state_page.dart';
import 'package:brick/core/vm/view_model.dart';

abstract class StatePageState<P extends StatePage, VM extends ViewModel>
    extends State<P> {
  late final VM vm;

  @override
  void initState() {
    super.initState();
    vm = onCreateViewModel();
    vm.onInitState();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appBar = onBuildAppBar(context);
    var body = ListenableBuilder(
      listenable: vm,
      builder: (ctx, child) => _buildContent(context),
    );

    return onBuildScaffold(context, appBar, body) ??
        Scaffold(
          appBar: appBar,
          backgroundColor: widget.backgroundColor,
          resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
          body: body,
        );
  }

  //==Desc:=================================================================

  Widget _buildContent(BuildContext context) {
    Widget child = _buildChild(context, vm.state);
    final dur = widget.transitionDuration ?? const Duration(milliseconds: 180);
    final curve = widget.transitionCurve ?? Curves.easeInOut;
    return AnimatedSwitcher(
      duration: dur,
      switchInCurve: curve,
      switchOutCurve: curve,
      // key: ValueKey(vm.state),
      transitionBuilder:
          widget.transitionBuilder ??
          (Widget child, Animation<double> animation) {
            // 默认：淡入淡出
            return FadeTransition(opacity: animation, child: child);
          },
      child: child,
    );
  }

  Widget _buildChild(BuildContext context, ViewState state) {
    return switch (state) {
      Loading(tip: final tip, progress: final progress) => Container(
        key: const ValueKey("loading"),
        child: onBuildLoading(context, tip: tip, progress: progress),
      ),
      Success() => Container(
        key: const ValueKey("success"),
        child: onBuildSuccess(context),
      ),
      Empty(e: final e) => Container(
        key: const ValueKey("empty"),
        child: onBuildEmpty(context, e: e),
      ),
      Error(e: final e) => Container(
        key: const ValueKey("error"),
        child: onBuildError(context, e: e),
      ),
    };
  }

  Scaffold? onBuildScaffold(
    BuildContext context,
    PreferredSizeWidget? appBar,
    Widget body,
  ) => null;

  Widget? onBuildLoading(
    BuildContext context, {
    String? tip,
    double? progress,
  }) => null;

  PreferredSizeWidget? onBuildAppBar(BuildContext context) => null;

  Widget? onBuildEmpty(BuildContext context, {AppException? e}) => null;

  Widget? onBuildError(BuildContext context, {AppException? e}) => null;

  VM onCreateViewModel();

  Widget onBuildSuccess(BuildContext context);
}
