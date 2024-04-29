import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:radius_app/services/storageManager.dart';

class LanguageNotifier with ChangeNotifier {
  // Current Locale EN/AR. Default is AR
  final Locale locale;
  LanguageNotifier({this.locale = const Locale.fromSubtags(languageCode: 'en')});

  // Class Instance
  static LanguageNotifier? of(BuildContext context){
    return Localizations.of<LanguageNotifier>(context, LanguageNotifier);
  }

  /// GET USER DEVICE LANGUAGE
  Future<String> getLocale() async{
    // Get language from app storage
    dynamic lang = await StorageManager.readData('localeKey');
    return ( lang != null ) ? lang : 'ar';
  }

  /// SET USER DEVICE LANGUAGE
  void setLocale( String localeKey){
    // Set language to app storage
    StorageManager.saveData('localeKey', localeKey);
    notifyListeners();
  }

  static const LocalizationsDelegate<LanguageNotifier> delegate = _MultiLanguagesDelegate();
  late Map<String, String> _localizedString;

  /// LOAD SELECTED LANGUAGES
  Future<bool> load() async{
    String jsonString
    = await rootBundle.loadString('assets/languages/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode( jsonString );
    _localizedString = jsonMap.map( (key, value) {
      return MapEntry(key, value.toString());
    });
    return true;
  }

  /// TRANSLATE TO SELECTED LANGUAGE BY KEY
  String translate( String key ){
    return _localizedString[key] as String;
  }
}

class _MultiLanguagesDelegate extends LocalizationsDelegate<LanguageNotifier> {
  // This delegate instance will never change
  // It can provide a constant constructor.
  const _MultiLanguagesDelegate();
  @override
  bool isSupported(Locale locale) {
    // Include all of your supported language codes here
    return ['en', 'ar'].contains(locale.languageCode);
  }
  /// read Json
  @override
  Future<LanguageNotifier> load(Locale locale) async {
    // MultiLanguages class is where the JSON loading actually runs

    LanguageNotifier localizations = LanguageNotifier(locale: locale);
    await localizations.load();
    return localizations;
  }
  @override
  bool shouldReload(_MultiLanguagesDelegate old) => false;
}