import 'package:flutter/material.dart';
import 'package:brick/core/data/app_exception.dart';
import 'package:brick/core/data/state.dart';

class ViewModel extends ChangeNotifier {
  ViewState _state = ViewState.loading();

  ViewState get state => _state;

  bool get isLoading => _state is Loading;

  bool get isSuccess => _state is Success;

  bool get isEmpty => _state is Empty;

  bool get isError => _state is Error;

  //==Desc:=================================================================

  void loading([String? tip, double? progress]) {
    _state = ViewState.loading(tip, progress);
    notifyListeners();
  }

  void success() {
    _state = ViewState.success();
    notifyListeners();
  }

  void empty([AppException? e]) {
    _state = ViewState.empty(e);
    notifyListeners();
  }

  void error([AppException? e]) {
    _state = ViewState.error(e);
    notifyListeners();
  }

  //==Desc:=================================================================

  void onInitState() {}
  void onDispose() {}

  @override
  void dispose() {
    try {
      onDispose();
    } finally {
      super.dispose();
    }
  }
}
