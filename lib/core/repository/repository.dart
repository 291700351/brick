import 'package:brick/core/data/api_response.dart';
import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/result.dart';
import 'package:brick/core/repository/cache_policy.dart';
import 'package:brick/core/repository/data_strategy.dart';
import 'package:brick/core/repository/fetch_strategy.dart';
import 'package:brick/core/repository/local_source.dart';

/// Repository 层，集中处理数据访问、缓存回退和统一异常语义。
///
/// 设计原则：
/// 1. 只暴露纯业务语义，不让 ViewModel 直接接触底层存储细节。
/// 2. 每种缓存策略都明确说明优先级和回退逻辑。
/// 3. 错误信息统一通过 [AppException] 传递，便于日志埋点和 UI 展示。
class Repository {
  /// 统一入口：按策略组合 remote / local / cache 的访问逻辑。
  ///
  /// 参数说明：
  /// - [remote]: 远程数据源
  /// - [local]: 本地数据源（仅 localOnly 用）
  /// - [localSaver]: 成功拉取后写入本地缓存
  /// - [localProvider]: 读取本地缓存
  /// - [strategy]: 数据源优先级策略
  /// - [fetchStrategy]: 自定义策略对象；localFirst 命中缓存后会立即返回，
  ///   并在后台刷新远端数据
  /// - [cacheKey]: localFirst 并发合并键，应包含用户、参数等请求作用域
  Future<Result<T>> fetch<T>({
    Future<Result<T>> Function()? remote,
    Future<Result<T>> Function()? local,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
    DataStrategy strategy = DataStrategy.remoteOnly,
    FetchStrategy<T>? fetchStrategy,
    String? cacheKey,
  }) async {
    final effectiveStrategy =
        fetchStrategy ?? FetchStrategy.fromDataStrategy(strategy);
    return effectiveStrategy.execute(
      remote: remote,
      local: local ?? localProvider,
      localSaver: localSaver,
      localProvider: localProvider,
      cacheKey: cacheKey,
    );
  }

  /// 仅访问远程源。
  Future<Result<T>> remoteOnly<T>(Future<Result<T>> Function() remote) async =>
      remote.call();

  /// 仅访问本地源。
  Future<Result<T>> localOnly<T>(Future<Result<T>> Function() local) async =>
      local.call();

  Future<Result<T>> remoteFirst<T>(
    Future<Result<T>> Function()? remote,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider,
  ) async {
    return RemoteFirstFetchStrategy<T>().execute(
      remote: remote,
      local: null,
      localSaver: localSaver,
      localProvider: localProvider,
    );
  }

  Future<Result<T>> localFirst<T>(
    Future<Result<T>> Function()? remote,
    Future<bool> Function(T?)? localSaver,
    Future<Result<T>> Function()? localProvider, {
    String? cacheKey,
  }) async {
    return LocalFirstFetchStrategy<T>().execute(
      remote: remote,
      local: null,
      localSaver: localSaver,
      localProvider: localProvider,
      cacheKey: cacheKey,
    );
  }

  //==Desc:本地存储相关=================================================================
  String _tsKey(String key) => "$key::ts";

  /// 保存 KV 缓存；TTL 时间戳保存为绝对过期时间。为了兼容旧代码，
  /// 也保留了已弃用的 [cacheExpire] 参数。
  Future<Result<bool>> kvSave<T>(
    KVLocalSource<T> source,
    String key,
    T data, {
    CachePolicy? policy,
    @Deprecated('Use policy instead.') Duration? cacheExpire,
  }) async {
    final effectivePolicy = policy ?? CachePolicy.fromDuration(cacheExpire);
    if (!effectivePolicy.enabled) return Result.successValue(false);

    var result = await source.save(key, data);
    if (!result.isSuccess || result.data != true) return result;

    if (effectivePolicy.maxAge == null) {
      final timestampDeleteResult = await source.deleteTs(_tsKey(key));
      if (!timestampDeleteResult.isSuccess ||
          timestampDeleteResult.data != true) {
        await source.deleteWithTs(key);
        return timestampDeleteResult;
      }
      return result;
    }

    final expiresAt = effectivePolicy.expirationFrom(DateTime.now());
    if (expiresAt != null) {
      final timestampResult = await source.setTs(
        _tsKey(key),
        expiresAt.millisecondsSinceEpoch,
      );
      if (!timestampResult.isSuccess || timestampResult.data != true) {
        await source.deleteWithTs(key);
        return timestampResult;
      }
    }
    return result;
  }

  /// 读取业务数据。
  ///
  /// [policy] 可用于显式控制缓存 TTL；如果未传，则沿用已存储的时间戳逻辑。
  Future<Result<T?>> kvGet<T>(
    KVLocalSource<T> source,
    String key, {
    CachePolicy? policy,
    @Deprecated('Use policy instead.') Duration? cacheExpire,
  }) async {
    final effectivePolicy = policy ?? CachePolicy.fromDuration(cacheExpire);
    if (!effectivePolicy.enabled) {
      return Result.failRaw(const AppException(-201, "缓存策略已禁用"));
    }

    var localRes = await source.get(key);
    if (!localRes.isSuccess) {
      return localRes;
    }

    final tsRes = await source.getTs(_tsKey(key));
    if (!tsRes.isSuccess) {
      return Result.failRaw(
        tsRes.error ?? const AppException(-202, "读取缓存时间戳失败"),
      );
    }
    if (tsRes.data == null && effectivePolicy.maxAge != null) {
      await source.deleteWithTs(key);
      return Result.failRaw(const AppException(-200, "缓存时间戳缺失"));
    }
    if (tsRes.data != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(tsRes.data!);
      if (!effectivePolicy.isValidUntil(expiresAt)) {
        await source.deleteWithTs(key);
        return Result.failRaw(const AppException(-200, "缓存已过期"));
      }
    }

    return localRes;
  }

  /// 删除key
  Future<Result<bool>> kvDelete<T>(KVLocalSource<T> source, String key) =>
      source.deleteWithTs(key);

  /// 清空
  Future<Result<bool>> kvClear<T>(KVLocalSource<T> source) => source.clear();

  //==Desc:Table存储相关=================================================================

  /// 插入/更新一条
  Future<Result<bool>> tableInsert<T, ID>(
    TableLocalSource<T, ID> source,
    T entity,
  ) => source.insert(entity);

  /// 根据主键删除
  Future<Result<bool>> tableDeleteById<T, ID>(
    TableLocalSource<T, ID> source,
    ID id,
  ) => source.deleteById(id);

  /// 根据主键删除
  Future<Result<bool>> tableUpdate<T, ID>(
    TableLocalSource<T, ID> source,
    T entity,
  ) => source.update(entity);

  /// 根据主键查询单条
  Future<Result<T?>> tableFindById<T, ID>(
    TableLocalSource<T, ID> source,
    ID id,
  ) => source.findById(id);

  /// 查询全部
  Future<Result<List<T>>> tableFindAll<T, ID>(TableLocalSource<T, ID> source) =>
      source.findAll();

  /// 分页查询
  Future<Result<List<T>>> tableFindPage<T, ID>(
    TableLocalSource<T, ID> source, {
    required int page,
    required int pageSize,
  }) => source.findPage(page: page, pageSize: pageSize);

  /// 清空整张表
  Future<Result<bool>> tableClear<T, ID>(TableLocalSource<T, ID> source) =>
      source.clear();

  //==Desc:=================================================================

  Future<Result<T>> wrapResponse<T>(Future<ApiResponse<T>> future) async {
    try {
      final resp = await future;
      return resp.isSuccess ? Result.success(resp) : Result.fail(resp);
    } catch (e) {
      return Result.failRaw(AppException(-999, "请求异常", cause: e));
    }
  }
}
