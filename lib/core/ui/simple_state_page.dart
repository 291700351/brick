import 'package:flutter/material.dart';
import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/ui/state_page.dart';
import 'package:brick/core/ui/state_page_state.dart';
import 'package:brick/core/vm/view_model.dart';

abstract class SimpleStatePage<VM extends ViewModel> extends StatePage {
  /// 路由参数
  final Object? arguments;
  final VM Function(Object? args) vmBuilder;

  const SimpleStatePage({
    super.key,
    this.arguments,
    required this.vmBuilder,
    super.backgroundColor,
    super.resizeToAvoidBottomInset,
    super.transitionDuration,
    super.transitionCurve,
    super.transitionBuilder,
  });

  @override
  State<SimpleStatePage<VM>> createState() => _SimpleStatePageState<VM>();

  Scaffold? onBuildScaffold(
    BuildContext context,
    VM vm,
    PreferredSizeWidget? appBar,
    Widget body,
  ) => null;

  PreferredSizeWidget? onBuildAppBar(BuildContext context, VM vm) => null;

  Widget? onBuildLoading(
    BuildContext context,
    VM vm, {
    String? tip,
    double? progress,
  }) => null;

  Widget? onBuildEmpty(BuildContext context, VM vm, {AppException? e}) => null;

  Widget? onBuildError(BuildContext context, VM vm, {AppException? e}) => null;

  Widget onBuildSuccess(BuildContext context, VM vm);
}

class _SimpleStatePageState<VM extends ViewModel>
    extends StatePageState<SimpleStatePage<VM>, VM> {
  @override
  VM onCreateViewModel() => widget.vmBuilder(widget.arguments);

  @override
  Scaffold? onBuildScaffold(
    BuildContext context,
    PreferredSizeWidget? appBar,
    Widget body,
  ) => widget.onBuildScaffold(context, vm, appBar, body);

  @override
  PreferredSizeWidget? onBuildAppBar(BuildContext context) =>
      widget.onBuildAppBar(context, vm);

  @override
  Widget? onBuildLoading(
    BuildContext context, {
    String? tip,
    double? progress,
  }) => widget.onBuildLoading(context, vm, tip: tip, progress: progress);

  @override
  Widget? onBuildEmpty(BuildContext context, {AppException? e}) =>
      widget.onBuildEmpty(context, vm, e: e);

  @override
  Widget? onBuildError(BuildContext context, {AppException? e}) =>
      widget.onBuildError(context, vm, e: e);

  @override
  Widget onBuildSuccess(BuildContext context) =>
      widget.onBuildSuccess(context, vm);
}
