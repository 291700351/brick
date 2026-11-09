import 'package:dio/dio.dart';
import 'package:brick/core/http/http_builder.dart';

class HttpHelper {
  static Dio? _defaultDio;
  static HttpBuilder? _defaultBuilder;

  /// 全局初始化入口，main 里面调用
  static void init(HttpBuilder builder) {
    _defaultBuilder = builder;
    _defaultDio = builder.build();
  }

  HttpHelper._();

  /// 获取默认Dio实例（全局默认配置）
  static Dio get dio {
    if (_defaultDio == null) {
      throw StateError("HttpManager 未初始化，请先调用 HttpManager.init");
    }
    return _defaultDio!;
  }

  /// 获取默认 builder，用于二次修改配置后 build 新 dio
  static HttpBuilder get defaultBuilder {
    if (_defaultBuilder == null) {
      throw StateError("HttpManager 未初始化，请先调用 HttpManager.init");
    }
    return _defaultBuilder!;
  }

  /// 基于默认builder复制一份，局部自定义参数，生成新Dio（多域名、独立HttpClient场景）
  static Dio newDio(void Function(HttpBuilder builder) config) {
    final builder = (_defaultBuilder?.clone() ?? HttpBuilder());
    config(builder);
    return builder.build();
  }

  /// 销毁默认Dio（登出/切换环境）
  static void dispose() {
    if (_defaultDio != null) {
      _defaultDio!.close();
    }
    _defaultDio = null;
    _defaultBuilder = null;
  }
}
