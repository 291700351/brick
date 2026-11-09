import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:brick/core/data/app_exception.dart';

import 'err_code.dart';

class ExceptionMapper {
  static AppException map(Object e, StackTrace stackTrace) {
    if (e is AppException) {
      return e;
    }

    late AppException ex;
    // ========== Dio 网络系列 ==========
    if (e is DioException) {
      ex = _mapDio(e);
    }
    // ========== Socket / TLS / HTTPS 底层网络 ==========
    else if (e is SocketException) {
      ex = AppException(ErrCode.netConnect, "无法连接服务器，请检查网络", cause: e);
    } else if (e is TlsException) {
      ex = AppException(ErrCode.tlsError, "证书校验失败，HTTPS握手异常", cause: e);
    } else if (e is HandshakeException) {
      ex = AppException(ErrCode.handshakeError, "SSL握手失败，证书不可信", cause: e);
    } else if (e is TimeoutException) {
      ex = AppException(ErrCode.timeout, "请求超时，请稍后重试", cause: e);
    }
    // ========== 数据解析、序列化 ==========
    else if (e is FormatException) {
      ex = AppException(ErrCode.format, "数据格式解析失败", cause: e);
    } else if (e is JsonUnsupportedObjectError) {
      ex = AppException(ErrCode.jsonSerialize, "JSON序列化失败，对象无法转json", cause: e);
    }
    // ========== 文件IO 异常 ==========
    else if (e is FileSystemException) {
      ex = AppException(ErrCode.fileIo, "文件读写失败", cause: e);
    }
    // ========== Hive本地存储 ==========
    // ========== Dart 内置核心异常（运行时） ==========
    else if (e is ArgumentError) {
      if (e.message.toString().contains("AES")) {
        ex = AppException(ErrCode.aes, "AES加密参数错误", cause: e);
      } else {
        ex = AppException(ErrCode.arg, "参数非法", cause: e);
      }
    } else if (e is StateError) {
      ex = AppException(ErrCode.state, "对象状态错误，操作不合法", cause: e);
    } else if (e is AssertionError) {
      ex = AppException(ErrCode.assertError, "程序断言失败", cause: e);
    } else if (e is TypeError) {
      ex = AppException(ErrCode.type, "类型转换错误", cause: e);
    } else if (e is NoSuchMethodError) {
      ex = AppException(ErrCode.noMethod, "调用了不存在的方法", cause: e);
    } else if (e is ConcurrentModificationError) {
      ex = AppException(ErrCode.modify, "集合遍历过程中被修改", cause: e);
    } else if (e is OutOfMemoryError) {
      ex = AppException(ErrCode.oom, "内存溢出", cause: e);
    } else if (e is StackOverflowError) {
      ex = AppException(ErrCode.stackOverflow, "栈溢出，递归深度过大", cause: e);
    }
    // ========== Flutter 原生通道、平台异常 ==========
    else if (e is PlatformException) {
      final rawCode = int.tryParse(e.code) ?? -1;
      ex = AppException(rawCode, e.message ?? "平台调用异常", cause: e);
    } else if (e is MissingPluginException) {
      ex = AppException(ErrCode.missingPlugin, "原生插件未注册", cause: e);
    } else if (e is FlutterError) {
      ex = AppException(ErrCode.flutterFrame, "Flutter框架渲染异常", cause: e);
    }
    // ========== Isolate 隔离线程 ==========
    else if (e is IsolateSpawnException) {
      ex = AppException(ErrCode.isolate, "Isolate创建失败", cause: e);
    }
    // ========== 兜底未知异常 ==========
    else {
      final rawMsg = kDebugMode ? "未知异常：$e" : "操作失败，请稍后重试";
      ex = AppException(ErrCode.unknown, rawMsg, cause: e);
    }

    // 可选埋点：日志上报
    // LogHelper.error(ex.msg, error: e, stackTrace: stackTrace);
    return ex;
  }

  static AppException _mapDio(DioException e) {
    final resp = e.response;
    final status = resp?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(ErrCode.timeout, "请求超时，请检查网络", cause: e);
      case DioExceptionType.connectionError:
        return AppException(ErrCode.netConnect, "无法连接服务器，请检查网络", cause: e);
      case DioExceptionType.badResponse:
        if (status == ErrCode.http401) {
          return AppException(ErrCode.http401, "登录已失效，请重新登录", cause: e);
        }
        if (status == ErrCode.http403) {
          return AppException(ErrCode.http403, "无访问权限", cause: e);
        }
        if (status == ErrCode.http404) {
          return AppException(ErrCode.http404, "接口地址不存在", cause: e);
        }
        if (status != null && status >= 500) {
          return AppException(status, "服务器内部错误", cause: e);
        }
        return AppException(status, "请求异常[$status]", cause: e);
      case DioExceptionType.cancel:
        return AppException(ErrCode.cancel, "请求已取消", cause: e);
      default:
        return AppException(ErrCode.netHttp, "网络请求异常", cause: e);
    }
  }
}
