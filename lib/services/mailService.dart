import 'dart:io';
import 'package:http/http.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:radius_app/services/storageManager.dart';

class MailerService{
  // final from = dotenv.env['MAILER_EMAIL'] as String;
  // final smtpServer= gmail(dotenv.env['MAILER_EMAIL'] as String, dotenv.env['MAILER_PASS'] as String);

  /// FUNCTION: SEND EMAIL
  Future<dynamic> sendEmail( String to, String subject, String body) async{
    try {
      // Read Credentials from app storage
      final from = await StorageManager.readData('smtpEmail'); // Mailer Email
      final pass  = await StorageManager.readData('smtpPass'); // Mailer Password
      if( from == null || pass == null ){
        return { "status" : false, "error" : 'SMTP credentials not found' };
      }
      // Init Connection
      final smtpServer= gmail(from as String, pass as String);
      // Prepare Message
      final message = Message()
        ..from = Address(from, 'Radius')
        ..recipients.add(to)
        ..subject = subject
        ..text = body
        ..html = body;
      // Send Message
      final sendReport = await send(message, smtpServer);
      return { "status" : true, "report" : sendReport.toString() };
    }
    on MailerException catch (e) {
      return { "status" : false, "error" : e.message };
    }
    on SocketException catch( e ){
      return { "status" : false, "error" : e.message };
    }
    on ClientException catch( e ){
      return { "status" : false, "error" : e.message };
    }
  }
}