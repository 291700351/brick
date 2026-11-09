import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:brick/core/data/api_response.dart';
import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/err_code.dart';
import 'package:brick/core/data/exception_mapper.dart';
import 'package:brick/core/data/result.dart';
import 'package:brick/core/http/http_builder.dart';
import 'package:brick/core/http/http_helper.dart';
import 'package:brick/core/repository/cache_policy.dart';
import 'package:brick/core/repository/data_strategy.dart';
import 'package:brick/core/repository/fetch_strategy.dart';
import 'package:brick/core/repository/local_source.dart';
import 'package:brick/core/repository/repository.dart';
import 'package:brick/core/ui/simple_state_page.dart';
import 'package:brick/core/vm/obx.dart';
import 'package:brick/core/vm/rx.dart';
import 'package:brick/core/vm/view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExceptionMapper', () {
    test('maps AES argument errors before generic ArgumentError handling', () {
      final ex = ExceptionMapper.map(
        ArgumentError('AES key length must be 16, 24 or 32 bytes'),
        StackTrace.current,
      );

      expect(ex.code, ErrCode.aes);
      expect(ex.msg, contains('AES'));
    });

    test(
      'maps Dio timeout and unauthorized responses to stable error codes',
      () {
        final timeout = ExceptionMapper.map(
          DioException(
            requestOptions: RequestOptions(path: '/timeout'),
            type: DioExceptionType.connectionTimeout,
          ),
          StackTrace.current,
        );
        final unauthorized = ExceptionMapper.map(
          DioException(
            requestOptions: RequestOptions(path: '/private'),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: '/private'),
              statusCode: 401,
            ),
          ),
          StackTrace.current,
        );

        expect(timeout.code, ErrCode.timeout);
        expect(unauthorized.code, ErrCode.http401);
      },
    );
  });

  group('HttpHelper', () {
    test('newDio copies base config and custom headers/interceptors', () {
      HttpHelper.init(
        HttpBuilder()
            .baseUrl('https://api.example.com')
            .header('X-App', 'flutter-scaffold')
            .addInterceptor(LogInterceptor(responseBody: false)),
      );

      final dio = HttpHelper.newDio((builder) {
        builder.header('X-Trace', 'trace-123');
      });

      expect(dio.options.baseUrl, 'https://api.example.com');
      expect(dio.options.headers['X-App'], 'flutter-scaffold');
      expect(dio.options.headers['X-Trace'], 'trace-123');
      expect(dio.interceptors.length, greaterThanOrEqualTo(2));

      HttpHelper.dispose();
    });
  });

  group('Result state model', () {
    test('supports explicit empty and failure states', () {
      final empty = Result.empty<String>(data: null);
      final failure = Result.failRaw<String>(const AppException(500, 'bad'));

      expect(empty.isEmpty, isTrue);
      expect(failure.isFailure, isTrue);
      expect(failure.isFailed, isTrue);
    });
  });

  group('ViewModel lifecycle', () {
    testWidgets('a page disposes its owned ViewModel when removed', (
      tester,
    ) async {
      final vm = _TrackingViewModel();
      await tester.pumpWidget(
        MaterialApp(home: _TestSimpleStatePage(vmBuilder: (_) => vm)),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(vm.onDisposeCalled, isTrue);
      expect(vm.disposeCalled, isTrue);
    });
  });

  group('CachePolicy', () {
    test('expires cached entries when maxAge has elapsed', () {
      final policy = const CachePolicy(maxAge: Duration(milliseconds: 10));
      final cachedAt = DateTime.now().subtract(
        const Duration(milliseconds: 100),
      );

      expect(policy.shouldUseCache(cachedAt), isFalse);
    });

    test('disabled cache policy never accepts stored data', () {
      final policy = const CachePolicy(
        enabled: false,
        maxAge: Duration(seconds: 1),
      );

      expect(policy.shouldUseCache(DateTime.now()), isFalse);
    });
  });

  group('FetchStrategy factory mapping', () {
    test(
      'maps every DataStrategy enum value to the expected strategy object',
      () {
        expect(
          FetchStrategy.fromDataStrategy<String>(DataStrategy.remoteOnly),
          isA<RemoteOnlyFetchStrategy<String>>(),
        );
        expect(
          FetchStrategy.fromDataStrategy<String>(DataStrategy.localOnly),
          isA<LocalOnlyFetchStrategy<String>>(),
        );
        expect(
          FetchStrategy.fromDataStrategy<String>(DataStrategy.localFirst),
          isA<LocalFirstFetchStrategy<String>>(),
        );
        expect(
          FetchStrategy.fromDataStrategy<String>(DataStrategy.remoteFirst),
          isA<RemoteFirstFetchStrategy<String>>(),
        );
      },
    );
  });

  group('Repository KV cache behavior', () {
    test('stores TTL timestamps as absolute expiry times', () async {
      final repo = Repository();
      final source = _MemoryKVSource<String>();
      final startedAt = DateTime.now();
      const maxAge = Duration(minutes: 1);

      await repo.kvSave(
        source,
        'token',
        'cached-value',
        policy: const CachePolicy(maxAge: maxAge),
      );

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        source.timestamps['token::ts']!,
      );
      expect(
        expiresAt.isAfter(startedAt.add(maxAge - const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        expiresAt.isBefore(
          DateTime.now().add(maxAge + const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('retains valid cache entries and rejects expired ones', () async {
      final repo = Repository();
      final source = _MemoryKVSource<String>();

      await repo.kvSave(
        source,
        'token',
        'cached-value',
        policy: const CachePolicy(maxAge: Duration(seconds: 1)),
      );

      final fresh = await repo.kvGet(
        source,
        'token',
        policy: const CachePolicy(maxAge: Duration(seconds: 1)),
      );

      expect(fresh.isSuccess, isTrue);
      expect(fresh.data, 'cached-value');

      await source.setTs(
        'token::ts',
        DateTime.now()
            .subtract(const Duration(seconds: 5))
            .millisecondsSinceEpoch,
      );
      final expired = await repo.kvGet(
        source,
        'token',
        policy: const CachePolicy(maxAge: Duration(seconds: 1)),
      );

      expect(expired.isFailure, isTrue);
      expect(expired.error?.msg, contains('缓存已过期'));
    });

    test(
      'checks stored expiry when kvGet has no explicit TTL policy',
      () async {
        final repo = Repository();
        final source = _MemoryKVSource<String>();
        await repo.kvSave(
          source,
          'token',
          'cached-value',
          policy: const CachePolicy(maxAge: Duration(minutes: 1)),
        );
        await source.setTs(
          'token::ts',
          DateTime.now()
              .subtract(const Duration(milliseconds: 100))
              .millisecondsSinceEpoch,
        );

        final result = await repo.kvGet(source, 'token');

        expect(result.isFailure, isTrue);
        expect((await source.get('token')).data, isNull);
      },
    );

    test('preserves cached data when reading its timestamp fails', () async {
      final repo = Repository();
      final source = _MemoryKVSource<String>()..failGetTs = true;
      await source.save('token', 'cached-value');

      final result = await repo.kvGet(
        source,
        'token',
        policy: const CachePolicy(maxAge: Duration(minutes: 1)),
      );

      expect(result.isFailure, isTrue);
      expect(result.error?.code, -3002);
      expect((await source.get('token')).data, 'cached-value');
    });

    test(
      'saving without TTL clears previous expiry and deleting clears metadata',
      () async {
        final repo = Repository();
        final source = _MemoryKVSource<String>();
        await repo.kvSave(
          source,
          'token',
          'temporary',
          policy: const CachePolicy(maxAge: Duration(minutes: 1)),
        );

        await repo.kvSave(source, 'token', 'permanent');
        expect(source.timestamps, isEmpty);
        expect((await repo.kvGet(source, 'token')).data, 'permanent');

        await repo.kvSave(
          source,
          'token',
          'temporary-again',
          policy: const CachePolicy(maxAge: Duration(minutes: 1)),
        );
        await repo.kvDelete(source, 'token');
        expect(source.timestamps, isEmpty);
        expect((await source.get('token')).data, isNull);
      },
    );

    test('rolls back data when clearing old TTL metadata fails', () async {
      final repo = Repository();
      final source = _MemoryKVSource<String>()..failDeleteTs = true;

      final result = await repo.kvSave(source, 'token', 'permanent');

      expect(result.isFailure, isTrue);
      expect((await source.get('token')).data, isNull);
    });

    test(
      'treats a just-expired absolute expiry timestamp as expired',
      () async {
        final repo = Repository();
        final source = _MemoryKVSource<String>();
        await source.save('token', 'cached-value');
        await source.setTs(
          'token::ts',
          DateTime.now()
              .subtract(const Duration(milliseconds: 100))
              .millisecondsSinceEpoch,
        );

        final result = await repo.kvGet(
          source,
          'token',
          policy: const CachePolicy(maxAge: Duration(seconds: 1)),
        );

        expect(result.isFailure, isTrue);
        expect(result.error?.msg, contains('缓存已过期'));
      },
    );

    test(
      'rejects and removes cached data when its TTL timestamp is missing',
      () async {
        final repo = Repository();
        final source = _MemoryKVSource<String>();
        await source.save('token', 'cached-value');

        final result = await repo.kvGet(
          source,
          'token',
          policy: const CachePolicy(maxAge: Duration(minutes: 1)),
        );

        expect(result.isFailure, isTrue);
        expect(result.error?.msg, contains('时间戳缺失'));
        expect((await source.get('token')).data, isNull);
      },
    );

    test(
      'does not write a TTL timestamp when saving the cache fails',
      () async {
        final repo = Repository();
        final source = _MemoryKVSource<String>()..failSave = true;

        final result = await repo.kvSave(
          source,
          'token',
          'cached-value',
          policy: const CachePolicy(maxAge: Duration(minutes: 1)),
        );

        expect(result.isFailure, isTrue);
        expect(source.timestamps, isEmpty);
      },
    );

    test('removes data when writing its TTL timestamp fails', () async {
      final repo = Repository();
      final source = _MemoryKVSource<String>()..failSetTs = true;

      final result = await repo.kvSave(
        source,
        'token',
        'cached-value',
        policy: const CachePolicy(maxAge: Duration(minutes: 1)),
      );

      expect(result.isFailure, isTrue);
      expect((await source.get('token')).data, isNull);
    });

    test(
      'disabled cache policy neither saves nor returns cached data',
      () async {
        final repo = Repository();
        final source = _MemoryKVSource<String>();
        const policy = CachePolicy(
          enabled: false,
          maxAge: Duration(minutes: 1),
        );

        final saveResult = await repo.kvSave(
          source,
          'token',
          'cached-value',
          policy: policy,
        );
        final readResult = await repo.kvGet(source, 'token', policy: policy);

        expect(saveResult.isSuccess, isTrue);
        expect(saveResult.data, isFalse);
        expect(readResult.isFailure, isTrue);
        expect((await source.get('token')).data, isNull);
      },
    );
  });

  group('Repository cache strategies', () {
    test(
      'fetchStrategy object and enum mode share the same semantics',
      () async {
        final repo = Repository();
        final objectResult = await repo.fetch<String>(
          fetchStrategy: const LocalFirstFetchStrategy<String>(),
          localProvider: () async {
            return Result.success(const ApiResponse(0, 'ok', 'cached-data'));
          },
          remote: () async {
            return Result.success(const ApiResponse(0, 'ok', 'remote-data'));
          },
        );

        final enumResult = await repo.fetch<String>(
          strategy: DataStrategy.localFirst,
          localProvider: () async {
            return Result.success(const ApiResponse(0, 'ok', 'cached-data'));
          },
          remote: () async {
            return Result.success(const ApiResponse(0, 'ok', 'remote-data'));
          },
        );

        expect(objectResult.data, 'cached-data');
        expect(enumResult.data, 'cached-data');
      },
    );

    test(
      'localFirst returns cached data and starts a remote refresh on hit',
      () async {
        final repo = Repository();
        var localCalls = 0;
        var remoteCalls = 0;

        final result = await repo.fetch<String>(
          strategy: DataStrategy.localFirst,
          localProvider: () async {
            localCalls++;
            return Result.success(const ApiResponse(0, 'ok', 'cached-data'));
          },
          remote: () async {
            remoteCalls++;
            return Result.success(const ApiResponse(0, 'ok', 'remote-data'));
          },
        );

        expect(result.data, 'cached-data');
        expect(result.isSuccess, isTrue);
        expect(localCalls, 1);
        expect(remoteCalls, 1);
      },
    );

    test(
      'localFirst returns empty cache immediately and refreshes remotely',
      () async {
        final repo = Repository();
        var remoteCalls = 0;

        final result = await repo.fetch<String>(
          strategy: DataStrategy.localFirst,
          localProvider: () async => Result.empty<String>(),
          remote: () async {
            remoteCalls++;
            return Result.success(const ApiResponse(0, 'ok', 'remote-data'));
          },
        );

        expect(result.isEmpty, isTrue);
        expect(remoteCalls, 1);
      },
    );

    test(
      'localFirst falls back to remote when local provider throws',
      () async {
        final repo = Repository();

        final result = await repo.fetch<String>(
          strategy: DataStrategy.localFirst,
          localProvider: () async => throw StateError('cache unavailable'),
          remote: () async =>
              Result.success(const ApiResponse(0, 'ok', 'remote-data')),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, 'remote-data');
      },
    );

    test('localFirst converts remote exceptions into failed results', () async {
      final repo = Repository();

      final result = await repo.fetch<String>(
        strategy: DataStrategy.localFirst,
        localProvider: () async =>
            Result.failRaw(const AppException(-1, 'cache miss')),
        remote: () async => throw StateError('network adapter failed'),
      );

      expect(result.isFailure, isTrue);
      expect(result.error?.code, ErrCode.state);
    });

    test(
      'localFirst coalesces same-key background requests and cache writes',
      () async {
        final repo = Repository();
        final remoteResult = Completer<Result<String>>();
        final cacheSaved = Completer<void>();
        var remoteCalls = 0;
        var saveCalls = 0;

        Future<Result<String>> fetchCached() => repo.fetch<String>(
          strategy: DataStrategy.localFirst,
          cacheKey: 'profile:user-1',
          localProvider: () async =>
              Result.success(const ApiResponse(0, 'ok', 'cached-profile')),
          remote: () {
            remoteCalls++;
            return remoteResult.future;
          },
          localSaver: (data) async {
            saveCalls++;
            cacheSaved.complete();
            return true;
          },
        );

        final first = await fetchCached();
        final second = await fetchCached();

        expect(first.data, 'cached-profile');
        expect(second.data, 'cached-profile');
        expect(remoteCalls, 1);

        remoteResult.complete(
          Result.success(const ApiResponse(0, 'ok', 'fresh-profile')),
        );
        await cacheSaved.future;
        expect(saveCalls, 1);
      },
    );

    test(
      'localFirst does not wait for remote refresh and saves refreshed data',
      () async {
        final repo = Repository();
        final remoteResult = Completer<Result<String>>();
        final refreshSaved = Completer<void>();
        String? savedValue;

        final result = await repo.fetch<String>(
          strategy: DataStrategy.localFirst,
          localProvider: () async =>
              Result.success(const ApiResponse(0, 'ok', 'cached-data')),
          remote: () => remoteResult.future,
          localSaver: (data) async {
            savedValue = data;
            refreshSaved.complete();
            return true;
          },
        );

        expect(result.data, 'cached-data');
        expect(savedValue, isNull);

        remoteResult.complete(
          Result.success(const ApiResponse(0, 'ok', 'refreshed-data')),
        );
        await refreshSaved.future;

        expect(savedValue, 'refreshed-data');
      },
    );

    test('localFirst falls back to remote when cache is missing', () async {
      final repo = Repository();
      var localCalls = 0;
      var remoteCalls = 0;

      final result = await repo.fetch<String>(
        strategy: DataStrategy.localFirst,
        localProvider: () async {
          localCalls++;
          return Result.failRaw(const AppException(-1, 'cache miss'));
        },
        remote: () async {
          remoteCalls++;
          return Result.success(const ApiResponse(0, 'ok', 'remote-data'));
        },
        localSaver: (data) async => true,
      );

      expect(result.data, 'remote-data');
      expect(localCalls, 1);
      expect(remoteCalls, 1);
    });

    test('localFirst keeps remote success when cache saving throws', () async {
      final repo = Repository();

      final result = await repo.fetch<String>(
        strategy: DataStrategy.localFirst,
        localProvider: () async =>
            Result.failRaw(const AppException(-1, 'cache miss')),
        remote: () async =>
            Result.success(const ApiResponse(0, 'ok', 'remote-data')),
        localSaver: (data) async => throw StateError('disk full'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'remote-data');
    });

    test('remoteFirst falls back to local when remote fails', () async {
      final repo = Repository();
      var remoteCalls = 0;
      var localCalls = 0;

      final result = await repo.fetch<String>(
        strategy: DataStrategy.remoteFirst,
        remote: () async {
          remoteCalls++;
          return Result.failRaw(const AppException(500, 'remote failed'));
        },
        localProvider: () async {
          localCalls++;
          return Result.success(const ApiResponse(0, 'ok', 'cached-data'));
        },
      );

      expect(result.data, 'cached-data');
      expect(remoteCalls, 1);
      expect(localCalls, 1);
    });

    test(
      'remoteOnly and localOnly strategy objects execute the correct source',
      () async {
        final repo = Repository();

        final remoteResult = await repo.fetch<String>(
          fetchStrategy: const RemoteOnlyFetchStrategy<String>(),
          remote: () async =>
              Result.success(const ApiResponse(0, 'ok', 'remote-data')),
        );

        final localResult = await repo.fetch<String>(
          fetchStrategy: const LocalOnlyFetchStrategy<String>(),
          localProvider: () async =>
              Result.success(const ApiResponse(0, 'ok', 'local-data')),
        );

        expect(remoteResult.data, 'remote-data');
        expect(localResult.data, 'local-data');
      },
    );

    test(
      'missing required data sources have explicit strategy outcomes',
      () async {
        final remoteOnly = await const RemoteOnlyFetchStrategy<String>()
            .execute();
        final localOnly = await const LocalOnlyFetchStrategy<String>()
            .execute();

        final localFirst = await const LocalFirstFetchStrategy<String>()
            .execute();
        final remoteFirst = await const RemoteFirstFetchStrategy<String>()
            .execute();
        expect(remoteOnly.error?.code, -100);
        expect(localOnly.error?.code, -101);
        expect(localFirst.isFailure, isTrue);
        expect(remoteFirst.isFailure, isTrue);
      },
    );
  });

  group('Reactive state', () {
    test('RxList mutation notifies listeners and keeps list immutable', () {
      final list = RxList<int>([1, 2]);
      var latest = list.value;
      list.addListener(() {
        latest = list.value;
      });

      list.add(3);
      expect(latest, [1, 2, 3]);

      list.removeAt(0);
      expect(latest, [2, 3]);
    });

    testWidgets(
      'Obx rebuilds from tracked Rx values without duplicate listeners',
      (tester) async {
        final count = Rx<int>(0);
        final name = Rx<String>('hello');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Obx(() {
                return Text('${count.value}-${name.value}');
              }),
            ),
          ),
        );

        expect(find.text('0-hello'), findsOneWidget);

        count.value = 1;
        await tester.pump();
        expect(find.text('1-hello'), findsOneWidget);

        name.value = 'world';
        await tester.pump();
        expect(find.text('1-world'), findsOneWidget);
      },
    );
  });
}

class _MemoryKVSource<T> implements KVLocalSource<T> {
  final Map<String, T> _values = {};
  final Map<String, int> _timestamps = {};
  bool failSave = false;
  bool failSetTs = false;
  bool failGetTs = false;
  bool failDeleteTs = false;

  Map<String, int> get timestamps => _timestamps;

  @override
  Future<Result<bool>> save(String key, T data) async {
    if (failSave) {
      return Result.failRaw(const AppException(-3002, 'write failed'));
    }
    _values[key] = data;
    return Result.successValue(true);
  }

  @override
  Future<Result<T?>> get(String key) async {
    return Result.successValue(_values[key]);
  }

  @override
  Future<Result<bool>> delete(String key) async {
    _values.remove(key);
    return Result.successValue(true);
  }

  @override
  Future<Result<int?>> getTs(String tsKey) async {
    if (failGetTs) {
      return Result.failRaw(const AppException(-3002, 'timestamp read failed'));
    }
    return Result.successValue(_timestamps[tsKey]);
  }

  @override
  Future<Result<bool>> setTs(String tsKey, int timestampMs) async {
    if (failSetTs) {
      return Result.failRaw(
        const AppException(-3002, 'timestamp write failed'),
      );
    }
    _timestamps[tsKey] = timestampMs;
    return Result.successValue(true);
  }

  @override
  Future<Result<bool>> deleteTs(String tsKey) async {
    if (failDeleteTs) {
      return Result.failRaw(
        const AppException(-3002, 'timestamp delete failed'),
      );
    }
    _timestamps.remove(tsKey);
    return Result.successValue(true);
  }

  @override
  Future<Result<bool>> deleteWithTs(String key) async {
    _values.remove(key);
    _timestamps.remove('$key::ts');
    return Result.successValue(true);
  }

  @override
  Future<Result<bool>> clear() async {
    _values.clear();
    _timestamps.clear();
    return Result.successValue(true);
  }
}

class _TrackingViewModel extends ViewModel {
  bool onDisposeCalled = false;
  bool disposeCalled = false;

  @override
  void onDispose() {
    onDisposeCalled = true;
  }

  @override
  void dispose() {
    disposeCalled = true;
    super.dispose();
  }
}

class _TestSimpleStatePage extends SimpleStatePage<_TrackingViewModel> {
  const _TestSimpleStatePage({required super.vmBuilder});

  @override
  Widget onBuildSuccess(BuildContext context, _TrackingViewModel vm) =>
      const Text('ready');
}
