import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:radius_app/services/userManager.dart';

class ChatService{
  final _firestore = FirebaseFirestore.instance;

  Future<dynamic> reportChat( dynamic data ) async {
    try{
      await _firestore.collection('reports').doc('report').update({
        "submissions" : FieldValue.arrayUnion([data]),
      });
      return { "status" : true, "msg" : 'Reported successfully' };
    }catch( e ){
      return { "status" : false, "msg" : e.toString() };
    }
  }

  Future<dynamic> uploadImage( File? image ) async{
    try{
      var request = http.MultipartRequest('POST', UserManager().getServerUrl( 'upload-image' ) );
      if( image != null ){
        String name = basename(image!.path);
        final fileValue =  await http.MultipartFile.fromPath(
          'image',
          image!.path,
          filename: 'image_$name.jpg',
        );
        request.files.add(fileValue);
        var res = await request.send();
        var response = await http.Response.fromStream(res);
        dynamic output = json.decode( response.body );
        if( response.statusCode == 200 ){
          return { "status" : true, "file" : output['file'] };
        }else{
          debugPrint( output['message'].toString() );
          return { "status" : false, "message" : output['message'] };
        }
      }
    }catch( e ){
      debugPrint(e.toString());
      return { "status" : false, "message" : e.toString() };
    }
  }
}