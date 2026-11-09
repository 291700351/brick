/// 统一缓存策略。
///
/// 通过显式声明缓存是否启用以及缓存 TTL，避免把 `Duration` 散落在业务代码中。
class CachePolicy {
  const CachePolicy({this.enabled = true, this.maxAge});

  /// 是否启用缓存读写。禁用时 Repository 不会返回或保存缓存。
  final bool enabled;

  /// 缓存有效期。为 `null` 表示永不过期。
  final Duration? maxAge;

  /// 从旧的 `Duration` 兼容构造。
  factory CachePolicy.fromDuration(Duration? maxAge, {bool enabled = true}) =>
      CachePolicy(enabled: enabled, maxAge: maxAge);

  bool get hasMaxAge => maxAge != null;

  /// Returns the absolute expiry time for an entry created at [cachedAt].
  /// KV storage persists this value, not the creation timestamp.
  DateTime? expirationFrom(DateTime cachedAt) {
    if (!enabled || maxAge == null) return null;
    return cachedAt.add(maxAge!);
  }

  /// Checks a stored absolute expiry time. A missing time is invalid when TTL
  /// is enabled, since the entry's age cannot be verified.
  bool isValidUntil(DateTime? expiresAt) {
    if (!enabled) return false;
    if (expiresAt == null) return maxAge == null;
    return DateTime.now().isBefore(expiresAt);
  }

  CachePolicy copyWith({bool? enabled, Duration? maxAge}) {
    return CachePolicy(
      enabled: enabled ?? this.enabled,
      maxAge: maxAge ?? this.maxAge,
    );
  }

  bool shouldUseCache(DateTime? cachedAt) {
    if (!enabled) return false;
    if (cachedAt == null) return false;
    if (maxAge == null) return true;
    return DateTime.now().isBefore(cachedAt.add(maxAge!));
  }
}
