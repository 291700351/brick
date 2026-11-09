import 'package:flutter/cupertino.dart';
import 'package:brick/core/vm/rx_tracker.dart';

class Rx<T> extends ValueNotifier<T> {
  Rx(super.value);

  @override
  T get value {
    RxTracker.instance.track(this);
    return super.value;
  }

  @override
  set value(T newValue) {
    if (identical(newValue, super.value) || newValue == super.value) {
      return;
    }
    super.value = newValue;
  }
}

/// 简写 obs 工厂函数
Rx<T> obs<T>(T value) => Rx<T>(value);

//=======
class RxList<T> extends Rx<List<T>> {
  RxList([List<T>? init]) : super(List<T>.unmodifiable(init ?? <T>[]));

  void add(T item) {
    value = List<T>.unmodifiable([...value, item]);
  }

  void remove(T item) {
    final next = List<T>.from(value)..remove(item);
    value = List<T>.unmodifiable(next);
  }

  void removeAt(int index) {
    final next = List<T>.from(value)..removeAt(index);
    value = List<T>.unmodifiable(next);
  }

  void clear() {
    value = List<T>.unmodifiable(List<T>.empty(growable: true));
  }
}

//=======
