// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodmngmt/main.dart';

void main() {
  testWidgets('App loads and shows home buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 驗證首頁按鈕存在
    expect(find.text('首頁'), findsOneWidget);
    expect(find.text('食物管理'), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
  });
}
