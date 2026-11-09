// 依赖收集管理器
import 'package:flutter/material.dart';

class RxTracker {
  static final RxTracker instance = RxTracker._();

  RxTracker._();

  final List<List<Listenable>> _stack = [];

  List<List<Listenable>> get stack => _stack;

  bool get isCollecting => _stack.isNotEmpty;

  void startCollect(List<Listenable> deps) {
    _stack.add(deps);
  }

  void endCollect() {
    if (_stack.isNotEmpty) {
      _stack.removeLast();
    }
  }

  void track(Listenable rx) {
    if (isCollecting && !_stack.last.contains(rx)) {
      _stack.last.add(rx);
    }
  }
}
