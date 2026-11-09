import 'package:brick/core/data/result.dart';

abstract class LocalSource {}

/// KV型本地存储抽象（SP / Hive / MMKV / Memory）
abstract class KVLocalSource<T> implements LocalSource {
  /// 读取业务数据
  Future<Result<T?>> get(String key);

  /// 写入业务数据
  Future<Result<bool>> save(String key, T data);

  /// 删除key
  Future<Result<bool>> delete(String key);

  /// 获取缓存的绝对过期时间（Unix 毫秒）。成功且值为 null 表示没有过期时间；
  /// 失败表示存储读取错误。
  Future<Result<int?>> getTs(String tsKey);

  /// 设置缓存的绝对过期时间（Unix 毫秒）。
  Future<Result<bool>> setTs(String tsKey, int timestampMs);

  /// 幂等删除缓存过期时间，但保留业务数据。
  Future<Result<bool>> deleteTs(String tsKey);

  /// 删除key + 配套的ts时间戳key
  Future<Result<bool>> deleteWithTs(String key);

  /// 清空
  Future<Result<bool>> clear();
}

/// 表结构型本地存储抽象（sqflite/sqlite、isar）
abstract class TableLocalSource<T, ID> implements LocalSource {
  /// 插入/更新一条
  Future<Result<bool>> insert(T entity);

  /// 根据主键删除
  Future<Result<bool>> deleteById(ID id);

  /// 根据主键删除
  Future<Result<bool>> update(T entity);

  /// 根据主键查询单条
  Future<Result<T?>> findById(ID id);

  /// 查询全部
  Future<Result<List<T>>> findAll();

  /// 分页查询
  Future<Result<List<T>>> findPage({required int page, required int pageSize});

  /// 清空整张表
  Future<Result<bool>> clear();
}
