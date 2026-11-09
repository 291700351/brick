class AppException implements Exception {
  final int? code;
  final String? msg;
  final Object? cause; //原始异常信息

  const AppException(this.code, this.msg, {this.cause});

  @override
  String toString() => (cause != null ? "$msg | cause:$cause" : msg) ?? "客户端异常";
}
