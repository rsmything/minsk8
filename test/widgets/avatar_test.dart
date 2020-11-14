// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minsk8/import.dart';

void main() {
  const imageUrl = 'https://www.fnordware.com/superpng/pngtest16rgba.png';
  group('MyAvatar', () {
    setUpAll(() => HttpOverrides.global = null);

    testWidgets('renders CircleAvatar', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MyAvatar()));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('has correct radius', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MyAvatar()));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 48);
    });

    testWidgets('renders backgroundImage if photo is not null', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MyAvatar(photo: imageUrl)));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNotNull);
    });

    testWidgets('renders icon if photo is null', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MyAvatar()));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNull);
      final icon = avatar.child as Icon;
      expect(icon.icon, Icons.person_outline);
      expect(icon.size, 48);
    });
  });
}
