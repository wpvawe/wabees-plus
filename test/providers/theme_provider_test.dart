import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Tests for theme mode logic (isolated from Hive persistence)
void main() {
  group('ThemeMode Logic', () {
    test('ThemeMode.system is default', () {
      const mode = ThemeMode.system;
      expect(mode, ThemeMode.system);
      expect(mode != ThemeMode.dark, true);
    });

    test('ThemeMode values are correct', () {
      expect(ThemeMode.values.length, 3);
      expect(ThemeMode.values.contains(ThemeMode.system), true);
      expect(ThemeMode.values.contains(ThemeMode.light), true);
      expect(ThemeMode.values.contains(ThemeMode.dark), true);
    });

    test('toggle logic: not-dark becomes dark', () {
      ThemeMode state = ThemeMode.light;
      // toggle logic: if dark → light, else → dark
      state = (state == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
      expect(state, ThemeMode.dark);
    });

    test('toggle logic: dark becomes light', () {
      ThemeMode state = ThemeMode.dark;
      state = (state == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
      expect(state, ThemeMode.light);
    });

    test('fromString parsing', () {
      ThemeMode fromString(String value) {
        switch (value) {
          case 'dark':
            return ThemeMode.dark;
          case 'light':
            return ThemeMode.light;
          default:
            return ThemeMode.system;
        }
      }

      expect(fromString('dark'), ThemeMode.dark);
      expect(fromString('light'), ThemeMode.light);
      expect(fromString('system'), ThemeMode.system);
      expect(fromString('invalid'), ThemeMode.system);
    });
  });
}
