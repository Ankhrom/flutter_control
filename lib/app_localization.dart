import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_control/core.dart';

/// Defines language and asset path to file with localization data.
class LocalizationAsset {
  /// Locale key in iso2 standard (en, es, etc.).
  final String iso2Locale;

  /// Asset path to file with localization data (json).
  /// - /assets/localization/en.json
  final String assetPath;

  /// Default constructor
  LocalizationAsset(this.iso2Locale, this.assetPath);
}

/// Simple [Map] based localization.
/// - /assets/localization/en.json
class AppLocalization {
  /// key to shared preferences where preferred locale is stored.
  static const String preference_key = 'pref_locale';

  /// default app locale in iso2 standard.
  final String defaultLocale;

  /// List of available localization assets.
  /// LocalizationAssets defines language and asset path to file with localization data.
  final List<LocalizationAsset> assets;

  /// returns locale in iso2 standard (en, es, etc.).
  String get locale => _locale;

  /// Current locale in iso2 standard (en, es, etc.).
  String _locale;

  /// Current localization data.
  Map<String, dynamic> _data = Map();

  /// Enables debug mode for localization.
  /// When localization key isn't found for given locale, then [localize] returns key and current locale (key_locale).
  bool debug = true;

  bool get isActive => _data.length > 0;

  VoidCallback onLocalizationChanged;

  /// Default constructor
  AppLocalization(this.defaultLocale, this.assets, {bool preloadDefaultLocalization: true}) {
    if (preloadDefaultLocalization) {
      changeLocale(defaultLocale, preferred: false);
    }
  }

  /// returns current Locale of device.
  Locale deviceLocale(BuildContext context) {
    return Localizations.localeOf(context, nullOk: true);
  }

  /// changes localization to system language
  /// @preferred - true: changes localization to in app preferred language (if previously set).
  Future<bool> changeToSystemLocale(BuildContext context, {bool preferred: true}) async {
    final pref = preferred ? await AppControl.prefs(this).get(preference_key) : null;

    String locale;

    if (pref != null && isLocalizationAvailable(pref)) {
      locale = pref;
    } else {
      locale = deviceLocale(context)?.languageCode;
    }

    if (locale != null) {
      return await changeLocale(locale);
    }

    return false;
  }

  /// returns true if localization file is available and is possible to load it.
  bool isLocalizationAvailable(String iso2Locale) {
    for (final asset in assets) {
      if (asset.iso2Locale == iso2Locale) {
        return true;
      }
    }

    return false;
  }

  /// returns asset path for given locale or null if localization asset is not available.
  String getAssetPath(String iso2Locale) {
    for (final asset in assets) {
      if (asset.iso2Locale == iso2Locale) {
        return asset.assetPath;
      }
    }

    return null;
  }

  /// Changes localization data inside this object.
  /// If localization isn't available, default localization is then used.
  /// It can take a while because localization is loaded from json file.
  Future<bool> changeLocale(String iso2Locale, {bool preferred: true, VoidCallback onChanged}) async {
    if (iso2Locale == null || !isLocalizationAvailable(iso2Locale)) {
      print("localization not available: $iso2Locale");
      return false;
    }

    if (preferred) {
      AppControl.prefs(this).set(preference_key, iso2Locale);
    }

    if (_locale == iso2Locale) {
      return true;
    }

    _locale = iso2Locale;
    return await _initLocalization(getAssetPath(iso2Locale), onChanged);
  }

  /// Loads localization from asset file for given locale.
  Future<bool> _initLocalization(String path, VoidCallback onChanged) async {
    if (path == null) {
      print("invalid localization file path");
      return false;
    }

    final json = await rootBundle.loadString(path, cache: false);
    final data = jsonDecode(json);

    if (data != null) {
      data.forEach((key, value) => _data[key] = value);

      print("localization changed to: $path");

      if (onLocalizationChanged != null) {
        onLocalizationChanged();
      }

      if (onChanged != null) {
        onChanged();
      }

      return true;
    }

    print("localization failed to change: $path");

    return false;
  }

  /// Tries to localize text by given key.
  /// Enable/Disable debug mode to show/hide missing localizations.
  String localize(String key) {
    if (_data.containsKey(key)) {
      return _data[key];
    }

    return debug ? "${key}_$_locale" : '';
  }

  /// Updates value in current set.
  /// This update is only runtime and isn't stored to localization file.
  void update(String key, String value) => _data[key] = value;

  /// Tries to localize text by given key.
  /// Enable/Disable debug mode to show/hide missing localizations.
  String extractLocalization(Map map, {String iso2Locale, String defaultLocale}) {
    iso2Locale ??= this.locale;
    defaultLocale ??= this.defaultLocale;

    if (map != null) {
      if (map.containsKey(iso2Locale)) {
        return map[iso2Locale];
      }

      if (map.containsKey(defaultLocale)) {
        return map[defaultLocale];
      }
    }

    return debug ? "empty_{$iso2Locale}_$defaultLocale" : '';
  }
}
