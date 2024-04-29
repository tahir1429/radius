import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageManager {

  /// SAVE DATA TO APP STORAGE
  static void saveData(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    switch( value.runtimeType ){
      case int:
        prefs.setInt(key, value);
        break;
      case double:
        prefs.setDouble(key, value);
        break;
      case String:
        prefs.setString(key, value);
        break;
      case bool:
        prefs.setBool(key, value);
        break;
      default:
        debugPrint("Invalid Type ${value.runtimeType}");
        break;
    }
  }

  /// GET/READ DATA FROM APP STORAGE
  static Future<dynamic> readData(String key) async {
    // Get storage instance
    final prefs = await SharedPreferences.getInstance();
    // get value by key
    dynamic obj = prefs.get(key);
    // return value
    return obj;
  }

  /// SAVE USER DATA TO APP STORAGE
  static void saveUser( dynamic value, { String jwtToken = '' } ) async {
    // Get Storage Instance
    final prefs = await SharedPreferences.getInstance();
    if( value == null ){
      return;
    }
    // SET USER DATA
    final dynamic settings = value['settings'] ?? false;
    if( settings != false ){
      final visibility = value['settings']['visible'];
      prefs.setBool('visibility', visibility );
    }else{
      prefs.setBool('visibility', true );
    }

    final blockedByList = value['blockedBy'] ?? [];

    prefs.setString('user-fname', value['fname'] ?? '' );
    prefs.setString('user-lname', value['lname'] ?? '' );
    prefs.setString('user-name', value['username'] ?? '' );
    prefs.setString('user-email', value['email'] );
    prefs.setString('user-avatar_type', value['avatar']['type'] ?? '' );
    prefs.setString('user-avatar_url', value['avatar']['url'] ?? '' );
    prefs.setString('user-status_text', value['status']['text'] ?? '' );
    prefs.setString('user-status_option', value['status']['option'] ?? '' );
    prefs.setString('user-uid', value['_id'] );
    prefs.setString('user-fcm', value['tokens']['fcm'] ?? '' );
    prefs.setString('user-loc', jsonEncode( value['location'] ?? {}) );
    prefs.setString('user-block-list', blockedByList.toString() );
    if( jwtToken.isNotEmpty ){
      prefs.setString('user-token', jwtToken );
    }
  }

  /// GET USER DATA FROM APP STORAGE
  static Future<dynamic> getUser( ) async {
    // Get Storage Instance
    final prefs = await SharedPreferences.getInstance();
    // Get User Data
    dynamic location = prefs.get( 'user-loc' ) ?? '{}';
    dynamic fname = prefs.get( 'user-fname' ) ?? '';
    dynamic lname = prefs.get( 'user-lname' ) ?? '';
    dynamic user = {
      'fullname' : fname+' '+lname,
      'fname' : fname,
      'lname' : lname,
      'username' : prefs.get( 'user-name' ),
      'email' : prefs.get( 'user-email' ),
      'avatar_type' : prefs.get( 'user-avatar_type' ),
      'avatar_url' : prefs.get( 'user-avatar_url' ),
      'status_text' : prefs.get( 'user-status_text' ),
      'status_option' : prefs.get( 'user-status_option' ),
      'uid' : prefs.get( 'user-uid' ),
      'jwtToken' : prefs.get( 'user-token' ),
      'location' : jsonDecode( location ),
      'blockedBy' : (( prefs.get( 'user-block-list' ) ?? '') as String).split(','),
    };
    // Return User Object
    return user;
  }

  /// DELETE USER DATA FROM APP STORAGE
  static Future<bool> deleteUser() async {
    // Get Storage Instance
    final prefs = await SharedPreferences.getInstance();
    // Get All User Keys
    prefs.remove('user-fname' );
    prefs.remove('user-lname' );
    prefs.remove('user-name' );
    prefs.remove('user-email' );
    prefs.remove('user-avatar_type' );
    prefs.remove('user-avatar_url' );
    prefs.remove('user-status_text' );
    prefs.remove('user-status_option' );
    prefs.remove('user-uid' );
    prefs.remove('user-fcm' );
    prefs.remove('user-loc' );
    prefs.remove('user-token' );
    prefs.remove('user-block-list' );
    prefs.remove('visibility');
    return true;
  }

  /// DELETE DATA FROM APP STORAGE
  static Future<bool> deleteData(String key) async {
    // Get Storage Instance
    final prefs = await SharedPreferences.getInstance();
    // Remove By Key
    return prefs.remove(key);
  }
}