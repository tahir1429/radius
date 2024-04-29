import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {

  static Future<String?> uploadImage(File file, String userId) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      String fileName = path.basename(file.path)+DateTime.now().toString();
      Reference reference = storage.ref().child('users/$userId/$fileName');
      UploadTask uploadTask = reference.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }
}