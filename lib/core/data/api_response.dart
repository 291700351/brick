import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/result.dart';

class ApiResponse<T> {
  final int? _code;

  int get code => _code ?? -1000;
  final String? _msg;

  String get msg => _msg ?? "服务器数据异常，请刷新重试";
  final T? data;

  const ApiResponse(this._code, this._msg, this.data);

  AppException toException() => AppException(code, msg);

  bool get isSuccess => _code == 0;

  Result<T> toResult() {
    if (isSuccess) {
      return Result.success(this);
    } else {
      return Result.fail(this);
    }
  }
}
