///数据源策略
enum DataStrategy {
  /// 只走远程
  remoteOnly,

  /// 只走本地
  localOnly,

  /// 本地命中时立即返回，并在后台请求远端；远端成功后尝试更新缓存。
  /// 本地未命中时等待远端结果。后台刷新失败不会改变已返回的缓存结果。
  localFirst,

  /// 远程优先，失败降级本地
  remoteFirst,
}
