import 'package:brick/core/data/app_exception.dart';

sealed class ViewState {
  const ViewState();

  factory ViewState.loading([String? tip, double? progress]) =>
      Loading(tip: tip, progress: progress);

  factory ViewState.success() => const Success();

  factory ViewState.empty([AppException? e]) => Empty(e);

  factory ViewState.error([AppException? e]) => Error(e);
}

class Loading extends ViewState {
  final String? tip;
  final double? progress;

  const Loading({this.tip, this.progress});
}

class Success extends ViewState {
  const Success();
}

class Empty extends ViewState {
  final AppException? e;

  const Empty([this.e]);
}

class Error extends ViewState {
  final AppException? e;

  const Error([this.e]);
}
