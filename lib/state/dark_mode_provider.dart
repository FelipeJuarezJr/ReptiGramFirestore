import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkModeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  DarkModeProvider() {
    print('🌙 DarkModeProvider: Constructor called');
    _loadDarkModePreference();
  }

  Future<void> _loadDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      print('🌙 DarkModeProvider: Loaded preference - isDarkMode: $_isDarkMode');
      notifyListeners();
    } catch (e) {
      print('🌙 DarkModeProvider: Error loading dark mode preference: $e');
    }
  }

  Future<void> toggleDarkMode(bool value) async {
    print('🌙 DarkModeProvider: toggleDarkMode called with value: $value');
    print('🌙 DarkModeProvider: Previous state was: $_isDarkMode');
    _isDarkMode = value;
    print('🌙 DarkModeProvider: New state is: $_isDarkMode');
    print('🌙 DarkModeProvider: Calling notifyListeners()');
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', value);
      print('🌙 DarkModeProvider: Saved preference to SharedPreferences: $value');
    } catch (e) {
      print('🌙 DarkModeProvider: Error saving dark mode preference: $e');
    }
  }
} 