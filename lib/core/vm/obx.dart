import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:brick/core/vm/rx_tracker.dart';

//===
class Obx extends StatefulWidget {
  final Widget Function() builder;
  final bool debugLog;

  const Obx(this.builder, {super.key, this.debugLog = kDebugMode});

  @override
  State<Obx> createState() => _ObxState();
}

class _ObxState extends State<Obx> {
  final List<Listenable> _deps = [];

  void _removeAllListener() {
    for (final dep in _deps) {
      dep.removeListener(_onChange);
    }
    _deps.clear();
  }

  void _syncDeps(List<Listenable> currentDeps) {
    final toRemove = _deps.where((dep) => !currentDeps.contains(dep)).toList();
    for (final dep in toRemove) {
      dep.removeListener(_onChange);
    }

    final toAdd = currentDeps.where((dep) => !_deps.contains(dep)).toList();
    for (final dep in toAdd) {
      dep.addListener(_onChange);
    }

    _deps
      ..clear()
      ..addAll(currentDeps);
  }

  void _onChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDeps = <Listenable>[];
    RxTracker.instance.startCollect(currentDeps);
    late Widget child;
    try {
      child = widget.builder();
    } finally {
      RxTracker.instance.endCollect();
    }

    _syncDeps(currentDeps);

    if (widget.debugLog) {
      debugPrint("[Obx] collected ${_deps.length} dependencies");
    }

    return child;
  }

  @override
  void dispose() {
    _removeAllListener();
    super.dispose();
  }
}
