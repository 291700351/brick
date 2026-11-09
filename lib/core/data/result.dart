import 'package:brick/core/data/api_response.dart';

import 'app_exception.dart';

/// 统一数据返回状态模型。
///
/// 除了成功/失败之外，还显式支持 `empty`、`loading` 等状态，方便页面和
/// ViewModel 建模，而不必仅靠 `data == null` 或 `error == null` 进行隐式判断。
enum ResultStatus {
  loading,
  success,
  empty,
  failure,
}

class Result<T> {
  final T? data;
  final AppException? error;
  final ResultStatus status;

  const Result._({this.data, this.error, this.status = ResultStatus.success});

  bool get isSuccess => status == ResultStatus.success;

  bool get isEmpty => status == ResultStatus.empty;

  bool get isLoading => status == ResultStatus.loading;

  bool get isFailed => status == ResultStatus.failure || error != null;

  bool get isFailure => isFailed;

  bool get hasData => data != null;

  Result<T> onSuccess(void Function(T? data) callback) {
    if (isSuccess) {
      callback(data);
    }
    return this;
  }

  Result<T> onEmpty(void Function(T? data) callback) {
    if (isEmpty) {
      callback(data);
    }
    return this;
  }

  Result<T> onFail(void Function(AppException err) callback) {
    if (isFailed) callback(error!);
    return this;
  }

  static Result<T> loading<T>() => Result<T>._(status: ResultStatus.loading);

  static Result<T> empty<T>({T? data, AppException? error}) => Result<T>._(
        data: data,
        error: error,
        status: ResultStatus.empty,
      );

  static Result<T> success<T>(ApiResponse<T> resp) {
    return Result<T>._(data: resp.data, status: ResultStatus.success);
  }

  static Result<T> successValue<T>(T? data) {
    return Result<T>._(data: data, status: ResultStatus.success);
  }

  static Result<T> fail<T>(ApiResponse<T> resp) {
    return Result<T>._(
      error: resp.toException(),
      status: ResultStatus.failure,
    );
  }

  static Result<T> failRaw<T>(AppException e) {
    return Result<T>._(
      error: e,
      status: ResultStatus.failure,
    );
  }
}
