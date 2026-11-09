import 'dart:async';

import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/exception_mapper.dart';
import 'package:brick/core/data/result.dart';
import 'package:brick/core/repository/data_strategy.dart';

final Map<String, Future<Result<Object?>>> _inFlightRequests = {};

/// 可组合的数据获取策略。
///
/// 通过把 `remote/local` 与回退逻辑显式抽象成对象，Repository 不再直接
/// 维护 switch 分支，从而更容易扩展新的缓存模式（如 refresh-first、
/// stale-while-revalidate、token-guarded 等）。
abstract class FetchStrategy<T> {
  const FetchStrategy();

  Future<Result<T>> execute({
    Future<Result<T>> Function()? remote,
    Future<Result<T>> Function()? local,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
    String? cacheKey,
  });

  static FetchStrategy<T> fromDataStrategy<T>(DataStrategy strategy) {
    switch (strategy) {
      case DataStrategy.remoteOnly:
        return RemoteOnlyFetchStrategy<T>();
      case DataStrategy.localOnly:
        return LocalOnlyFetchStrategy<T>();
      case DataStrategy.localFirst:
        return LocalFirstFetchStrategy<T>();
      case DataStrategy.remoteFirst:
        return RemoteFirstFetchStrategy<T>();
    }
  }
}

class RemoteOnlyFetchStrategy<T> extends FetchStrategy<T> {
  const RemoteOnlyFetchStrategy();

  @override
  Future<Result<T>> execute({
    Future<Result<T>> Function()? remote,
    Future<Result<T>> Function()? local,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
    String? cacheKey,
  }) async {
    if (remote == null) {
      return Result.failRaw(const AppException(-100, '缺少 remote 参数'));
    }
    return remote.call();
  }
}

class LocalOnlyFetchStrategy<T> extends FetchStrategy<T> {
  const LocalOnlyFetchStrategy();

  @override
  Future<Result<T>> execute({
    Future<Result<T>> Function()? remote,
    Future<Result<T>> Function()? local,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
    String? cacheKey,
  }) async {
    final localSource = local ?? localProvider;
    if (localSource == null) {
      return Result.failRaw(const AppException(-101, '缺少 local 参数'));
    }
    return localSource.call();
  }
}

class LocalFirstFetchStrategy<T> extends FetchStrategy<T> {
  const LocalFirstFetchStrategy();

  @override
  Future<Result<T>> execute({
    Future<Result<T>> Function()? remote,
    Future<Result<T>> Function()? local,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
    String? cacheKey,
  }) async {
    final localSource = local ?? localProvider;
    Result<T>? localRes;
    if (localSource != null) {
      try {
        localRes = await localSource();
      } catch (error, stackTrace) {
        localRes = Result.failRaw(ExceptionMapper.map(error, stackTrace));
      }
    }

    if (localRes != null && (localRes.isSuccess || localRes.isEmpty)) {
      if (remote != null) {
        unawaited(_runRemote(remote, localSaver, cacheKey));
      }
      return localRes;
    }

    if (remote != null) {
      return _runRemote(remote, localSaver, cacheKey);
    }

    if (localRes != null) {
      return localRes;
    }

    return Result.failRaw(const AppException(-103, '本地缓存失效，且未提供远程请求'));
  }
}

Future<Result<T>> _runRemote<T>(
  Future<Result<T>> Function() remote,
  Future<bool> Function(T?)? localSaver,
  String? cacheKey,
) async {
  if (cacheKey == null || cacheKey.isEmpty) {
    return _callRemoteAndSave(remote, localSaver);
  }

  final requestKey = '${T.toString()}::$cacheKey';
  final existing = _inFlightRequests[requestKey];
  if (existing != null) {
    return await existing as Result<T>;
  }

  final request = _callRemoteAndSave(remote, localSaver);
  final sharedRequest = request.then<Result<Object?>>((result) => result);
  _inFlightRequests[requestKey] = sharedRequest;
  try {
    return await request;
  } finally {
    if (identical(_inFlightRequests[requestKey], sharedRequest)) {
      _inFlightRequests.remove(requestKey);
    }
  }
}

Future<Result<T>> _callRemoteAndSave<T>(
  Future<Result<T>> Function() remote,
  Future<bool> Function(T?)? localSaver,
) async {
  try {
    final remoteResult = await remote();
    if (remoteResult.isSuccess) {
      try {
        await localSaver?.call(remoteResult.data);
      } catch (_) {
        // A cache write failure must not replace the successful remote result.
      }
    }
    return remoteResult;
  } catch (error, stackTrace) {
    return Result.failRaw(ExceptionMapper.map(error, stackTrace));
  }
}

class RemoteFirstFetchStrategy<T> extends FetchStrategy<T> {
  const RemoteFirstFetchStrategy();

  @override
  Future<Result<T>> execute({
    Future<Result<T>> Function()? remote,
    Future<Result<T>> Function()? local,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
    String? cacheKey,
  }) async {
    final remoteRes = await remote?.call();
    if (remoteRes != null && remoteRes.isSuccess) {
      try {
        await localSaver?.call(remoteRes.data);
      } catch (_) {
        // 缓存失败不影响当前结果返回
      }
      return remoteRes;
    }

    final localSource = local ?? localProvider;
    final localRes = await localSource?.call();
    if (localRes != null && localRes.isSuccess) {
      return localRes;
    }

    if (remoteRes != null) {
      return remoteRes;
    }

    if (localRes != null) {
      return localRes;
    }

    return Result.failRaw(const AppException(-104, '远程请求数据失败，且未提供本地缓存数据'));
  }
}
