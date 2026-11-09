# brick
[![Pub](https://img.shields.io/pub/v/brick.svg)](https://pub.dev/packages/brick)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Flutter Brick 是一套轻量脚手架套件，面向后台管理、仪表盘类项目。
> 内置多状态页面、ViewModel + Rx 响应式、统一异常 & Result 返回、Retrofit 网络封装、Repository 分层数据源。

## ✨ Features
- ✅ **多状态页面组件**：内置 `Loading / Empty / Success / Error`，自带状态切换动画
- ✅ **无第三方响应式 Rx**：Obx 自动依赖收集，类似 GetX 体验，底层基于原生 `Listenable`
- ✅ **统一结果包装 `Result<T>`** + 全局异常映射 `AppException`
- ✅ **统一工具 `safeCall`**：自动捕获异常、转换为业务异常
- ✅ **Dio + Retrofit** 网络封装，统一请求拦截
- ✅ **Repository 分层架构**：远端网络 + 本地缓存数据源，可灵活切换数据源策略
- ✅ 适配后台管理项目，可直接作为基础底座快速开发业务页面

## 📦 Installation
### 方式1：本地依赖（推荐自用）
```yaml
dependencies:
  brick:
    path: ../brick
