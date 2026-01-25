

import 'dart:html' as html;

import '../io.dart';

import '_browser_http_client_impl.dart';

String? get htmlWindowOrigin => html.window.origin;

String get locale {
  final languages = html.window.navigator.languages;
  if (languages != null && languages.isNotEmpty) {
    return languages.first;
  }
  return 'en-US';
}

String get operatingSystem {
  final s = html.window.navigator.userAgent.toLowerCase();
  if (s.contains('iphone') ||
      s.contains('ipad') ||
      s.contains('ipod') ||
      s.contains('watch os')) {
    return 'ios';
  }
  if (s.contains('mac os')) {
    return 'macos';
  }
  if (s.contains('fuchsia')) {
    return 'fuchsia';
  }
  if (s.contains('android')) {
    return 'android';
  }
  if (s.contains('linux') || s.contains('cros') || s.contains('chromebook')) {
    return 'linux';
  }
  if (s.contains('windows')) {
    return 'windows';
  }
  return '';
}

String get operatingSystemVersion {
  final userAgent = html.window.navigator.userAgent;

  // Android?
  {
    final regExp = RegExp('Android ([a-zA-Z0-9.-_]+)');
    final match = regExp.firstMatch(userAgent);
    if (match != null) {
      final version = match.group(1) ?? '';
      return version;
    }
  }

  // iPhone OS?
  {
    final regExp = RegExp('iPhone OS ([a-zA-Z0-9.-_]+) ([a-zA-Z0-9.-_]+)');
    final match = regExp.firstMatch(userAgent);
    if (match != null) {
      final version = (match.group(2) ?? '').replaceAll('_', '.');
      return version;
    }
  }

  // Mac OS X?
  {
    final regExp = RegExp('Mac OS X ([a-zA-Z0-9.-_]+)');
    final match = regExp.firstMatch(userAgent);
    if (match != null) {
      final version = (match.group(1) ?? '').replaceAll('_', '.');
      return version;
    }
  }

  // Chrome OS?
  {
    final regExp = RegExp('CrOS ([a-zA-Z0-9.-_]+) ([a-zA-Z0-9.-_]+)');
    final match = regExp.firstMatch(userAgent);
    if (match != null) {
      final version = match.group(2) ?? '';
      return version;
    }
  }

  // Windows NT?
  {
    final regExp = RegExp('Windows NT ([a-zA-Z0-9.-_]+)');
    final match = regExp.firstMatch(userAgent);
    if (match != null) {
      final version = (match.group(1) ?? '');
      return version;
    }
  }

  return '';
}

HttpClient newHttpClient() => BrowserHttpClientImpl();
