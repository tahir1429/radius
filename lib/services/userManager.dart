import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/chatService.dart';
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class UserManager{
  final geo = GeoFlutterFire();
  ChatService chatService = ChatService();
  final SocketSingleton ss = SocketSingleton();

  /// REGISTER USER
  Future<dynamic> register( dynamic data, File? image ) async {
    try {
      var request = http.MultipartRequest('POST', getServerUrl( 'user/register' ) );
      if( image != null ){
        // String name = basename(image!.path);
        // final fileValue =  await http.MultipartFile.fromPath(
        //   'image',
        //   image!.path,
        //   filename: 'image_$name.jpg',
        // );
        // request.files.add(fileValue);
      }
      for (var item in data.entries) {
        request.fields[item.key] = item.value;
      }
      var res = await request.send();
      var response = await http.Response.fromStream(res);

      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'], "token" : output['token'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// COMPLETE USER REGISTRATION
  Future<dynamic> completeRegistration( dynamic data, File? image ) async {
    try {
      var request = http.MultipartRequest('POST', getServerUrl( 'user/complete-registration' ) );
      if( image != null ){
        String name = basename(image!.path);
        final fileValue =  await http.MultipartFile.fromPath(
          'image',
          image!.path,
          filename: 'image_$name.jpg',
        );
        request.files.add(fileValue);
      }
      for (var item in data.entries) {
        request.fields[item.key] = item.value;
      }
      var res = await request.send();
      var response = await http.Response.fromStream(res);

      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'], "token" : output['token'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// LOGIN USER
  Future<dynamic> login(dynamic emailAddress, dynamic password) async {
    try{
      final response = await http.post( getServerUrl( 'user/login' ) , body: {
        'email' : emailAddress,
        'pass'  : password,
      });

      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'], "token" : output['token'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// SIGN-OUT USER
  Future<void> signOut() async {
    final response = await StorageManager.getUser();
    if( response != null ){
      String uid = response['uid'];
      await StorageManager.deleteUser();
      if( ss.socket.connected && uid.isNotEmpty ){
        ss.socket.emit('clear-chats', { "uid" : uid });
        ss.socket.emit('set-user-status', { "uid" : uid, "status" : false });
        ss.socket.clearListeners();
        ss.socket.disconnect();
        ss.socket.dispose();
      }
    }
  }

  /// VERIFY - IF USERNAME IS ALREADY TAKEN
  Future<dynamic> isUsernameTaken( String username ) async {
    try{
      final response = await http.post( getServerUrl( 'user/check-duplicate' ) , body: {
        'username' : username,
        'type' : 'username'
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "exist" : output['exist'] };
      }
      else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// VERIFY - IF EMAIL IS ALREADY TAKEN
  Future<dynamic> isEmailTaken( String email ) async {
    try{
      final response = await http.post( getServerUrl( 'user/check-duplicate' ) , body: {
        'email' : email,
        'type' : 'email'
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "exist" : output['exist'] };
      }
      else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// CREATE USER STORY
  Future<dynamic> createStory( File image, String caption, String mediaType, dynamic uid ) async{
    try {
      var request = http.MultipartRequest('POST', getServerUrl( 'user/create-story' ) );
      if( image != null ){
        String name = basename(image!.path);
        final fileValue =  await http.MultipartFile.fromPath(
          'file',
          image!.path,
          filename: 'image_$name.jpg',
        );
        request.files.add(fileValue);
      }
      request.fields['caption'] = caption;
      request.fields['uid']  = uid;
      request.fields['type'] = mediaType;

      var res = await request.send();
      var response = await http.Response.fromStream(res);

      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "story" : output['story'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// GET USER STORY
  Future<dynamic> getMyStories( dynamic uid ) async{
    try{
      final response = await http.post( getServerUrl( 'user/get-story' ) , body: {
        'uid' : uid,
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "stories" : output['stories'] };
      }
      else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// DELETE USER STORY
  Future<dynamic> deleteMyStories( dynamic uid, String storyId, String url ) async{
    try{
      final response = await http.post( getServerUrl( 'user/delete-story' ) , body: {
        'uid' : uid,
        'storyId' : storyId,
        'url' : url
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true };
      }
      else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// UPDATE USER AVATAR OR PROFILE PICTURE
  Future<dynamic> updateUserAvatar( String uid, dynamic data, File? image ) async {
    try{
      var request = http.MultipartRequest('POST', getServerUrl( 'user/update-avatar' ) );
      if( image != null && data['type'] == 'network' ){
        String name = basename(image!.path);
        final fileValue =  await http.MultipartFile.fromPath(
          'image',
          image!.path,
          filename: name,
        );
        request.files.add(fileValue);
      }

      for (var item in data.entries) {
        request.fields[item.key] = item.value;
      }
      request.fields['uid'] = uid;

      var res = await request.send();
      var response = await http.Response.fromStream(res);

      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user']  };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// UPDATE USER BIO
  Future<dynamic> updateUserBio( String uid, String statusOption, String statusText ) async {
    try{
      final response = await http.post( getServerUrl( 'user/update-bio' ) , body: {
        'text'   : statusText,
        'option' : statusOption,
        'uid'    : uid,
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// UPDATE USER FCM (NOTIFICATION) TOKEN
  Future<dynamic> updateUserFCMToken( String uid, String token ) async {
    try{
      final response = await http.post( getServerUrl( 'user/update-fcm-token' ) , body: {
        'token' : token,
        'uid' : uid
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// UPDATE USER AVAILABILITY (ONLINE-OFFLINE)
  void updateUserAvailability( String uid, bool isOnline ) async {
    try{
      await http.post( getServerUrl( 'user/update-availability' ) , body: {
        'isOnline' : (isOnline) ? 'true' : 'false',
        'uid' : uid
      });
    }
    on SocketException catch( e ){
      debugPrint(e.message);
    }
    on ClientException catch( e ){
      debugPrint(e.message);
    }
  }

  /// UPDATE USER CURRENT LOCATION
  Future<dynamic> updateUserLocation( String uid, dynamic lat, dynamic lng) async {
    try{
      GeoFirePoint myLocation = geo.point(latitude: lat, longitude: lng);
      final response = await http.post( getServerUrl( 'user/update-location' ) , body: {
        'latitude' :  '${myLocation.geoPoint.latitude}',
        'longitude' : '${myLocation.geoPoint.longitude}',
        'geohash' : '${myLocation.data["geohash"]}',
        'uid' : uid
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// GET USER BY Either Email or ID
  Future<dynamic> getUserBy( { email = '', id = '' }) async{
    try{
      final response = await http.post( getServerUrl( 'user/find-single-user' ) , body: {
        'email' : email,
        'id'    : id,
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'] };
      }
      else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// GET USER BY EMAIL
  Future<dynamic> getUserByEmail( String email ) async{
    try{
      final response = await http.post( getServerUrl( 'user/find-by-email' ) , body: {
        'email' : email,
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "user" : output['user'] };
      }
      else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// GET NEARBY USERS OF USER'S CURRENT LOCATION WITHIN DEFINED RADIUS
  Future<dynamic> getNearbyUsers( uid, center, radius) async{
    try{
      dynamic token = await StorageManager.readData('user-token');
      final response = await http.post( getServerUrl( 'user/find-nearby' ) , headers: {
            "x-access-token": token
          },
          body: {
            'latitude' :  '${center.geoPoint.latitude}',
            'longitude' : '${center.geoPoint.longitude}',
            'radius' : '$radius',
            'uid' : uid
          }
      );
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "users" : output['users'] };
      }else{
        debugPrint( output['code'].toString() );
        return { "status" : false, "code" : output['code'], "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// UPDATE USER PASSWORD
  Future<dynamic> updatePassword( String uid,  dynamic password ) async{
    try{
      final response = await http.post( getServerUrl( 'user/update-password' ) , body: {
        'uid' : uid,
        'password' : password,
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true };
      }else{
        debugPrint( output.toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// TOGGLE (BLOCK - UN-BLOCK) USER
  Future<dynamic> toggleBlock( String blockBy, String blockTo, { status = true } ) async{
    try{
      final response = await http.post( getServerUrl( 'user/toggle-block' ) , body: {
        'blockBy' : blockBy,
        'blockTo' : blockTo,
        'block' : '$status'
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "output" : output['output'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// GET USER BLOCKED LIST
  Future<dynamic> getBlockedList( String uid ) async {
    try{
      final response = await http.post( getServerUrl( 'user/block-list' ) , body: {
        'uid' : uid
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "users" : output['users'] };
      }else{
        debugPrint( output['message'].toString() );
        return { "status" : false, "message" : output['message'] };
      }
    }
    on SocketException catch( e ){
      return { "status" : false, "message" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "message" : e.message };
    }
  }

  /// CHECK IF USER IS ALREADY LOGGED-IN/SIGNED-OUT
  Future<bool> isLoggedIn() async {
    final currentUser = await StorageManager.getUser();
    String jwtToken = currentUser['jwtToken'] ?? '';
    if( currentUser != null && jwtToken.isNotEmpty ){
      return true;
    } else {
      return false;
    }
  }

  /// GET SERVER URL
  Uri getServerUrl( route ){
    final protocol   = dotenv.env['SERVER_PROTOCOL'];
    final serverPath = dotenv.env['SERVER_URL'];
    Uri serverUrl;
    if( protocol == 'http' ){
      serverUrl = Uri.http( '$serverPath' , route);
    }else{
      serverUrl = Uri.https( '$serverPath' , route);
    }
    return serverUrl;
  }
}
