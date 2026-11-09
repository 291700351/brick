// err_code.dart
class ErrCode {
  // 网络层 Dio / Socket 相关
  static const int netHttp = -1000;
  static const int netConnect = -1001;
  static const int timeout = -1002;
  static const int format = -1003;
  static const int cancel = -1004;
  static const int tlsError = -1005;
  static const int handshakeError = -1006;
  static const int jsonSerialize = -1007;

  // Hive 本地存储
  static const int hive = -3001;
  static const int fileIo = -3002;

  // Dart 运行时异常
  static const int arg = -2003;
  static const int state = -2004;
  static const int assertError = -2001;
  static const int type = -2002;
  static const int noMethod = -2005;
  static const int modify = -2006;
  static const int oom = -2007;
  static const int stackOverflow = -2008;

  // Flutter 平台插件
  static const int platform = -4000;
  static const int missingPlugin = -4001;
  static const int flutterFrame = -4002;

  // Isolate
  static const int isolate = -5001;

  // 加密 AES
  static const int aes = -6001;

  // 兜底未知
  static const int unknown = -9999;

  // HTTP 业务状态码（后端标准）
  static const int http401 = 401;
  static const int http403 = 403;
  static const int http404 = 404;
}
