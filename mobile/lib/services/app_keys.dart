import 'package:flutter/material.dart';

/// 全局导航 Key：让挂在 MaterialApp.builder 层（Navigator 之上）的悬浮球
/// 也能通过 navigatorKey.currentContext 找到 Navigator 来弹出聊天面板。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
