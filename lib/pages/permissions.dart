import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:radius_app/services/languageManager.dart';
import '../services/themeManager.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';

//FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class CustomPermissions extends StatefulWidget {
  const CustomPermissions({Key? key}) : super(key: key);

  @override
  State<CustomPermissions> createState() => _CustomPermissionsState();
}

class _CustomPermissionsState extends State<CustomPermissions> {
  UserManager userManager = UserManager();
  final messaging = FirebaseMessaging.instance;
  PermissionStatus locationPermissionStatus = PermissionStatus.denied;
  PermissionStatus notificationPermissionStatus = PermissionStatus.denied;
  bool isUserLoggedIn = false;
  bool isChecking = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _requestNotificationPermission();
  }

  // Validate Location Permission
  Future<void> _checkPermissionStatus() async {
    try{
      final status = await Permission.locationWhenInUse.status;
      isUserLoggedIn = await userManager.isLoggedIn();
      final userInfo = await StorageManager.getUser();
      locationPermissionStatus = status;
      if( isUserLoggedIn && mounted ){
        if( userInfo['username'] != null && userInfo['username'] != '' ){
          Navigator.pushReplacementNamed(context, '/home');
        }else{
          Navigator.pushReplacementNamed(context, '/setup-avatar');
        }
      }else{
        Navigator.pushReplacementNamed(context, '/get-started');
      }
      print('CHEKCING PERMISSION');
      // if( status.isGranted ){
      //
      // }
      if( mounted ){
        setState(() {
          isChecking = false;
        });
      }
    }catch( e ){
      debugPrint( e.toString() );
    }
  }

  // Request Location Permission
  Future<void> _requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    final userInfo = await StorageManager.getUser();

    setState(() {
      locationPermissionStatus = status;

      // if( status.isGranted ){
      //   if( isUserLoggedIn && userInfo!=null && mounted ){
      //     if( userInfo['username'] != null && userInfo['username'] != '' ){
      //       Navigator.pushReplacementNamed(context, '/home');
      //     }else{
      //       Navigator.pushReplacementNamed(context, '/setup-avatar');
      //     }
      //   }else{
      //     Navigator.pushReplacementNamed(context, '/get-started');
      //   }
      // }
    });
    dynamic isExist = await userManager.getUserByEmail( userInfo['email'] );
    if( isUserLoggedIn && userInfo!=null && mounted ){
      if( isExist['status'] == false ){
        await StorageManager.deleteUser();
        if( mounted ){
          Navigator.of(context)
              .pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (
                      context) => const SignIn()),
                  (Route<
                  dynamic> route) => false);
        }
      }
      else if( userInfo['username'] != null && userInfo['username'] != '' ){
        Navigator.pushReplacementNamed(context, '/home');
      }else{
        Navigator.pushReplacementNamed(context, '/setup-avatar');
      }
    }else{
      Navigator.pushReplacementNamed(context, '/get-started');
    }
  }

  // Request Notification Permission
  void _requestNotificationPermission() async {
    try{
      // Permission Settings
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      // Check if permission status - Authorized
      if( settings.authorizationStatus == AuthorizationStatus.authorized ){
        notificationPermissionStatus = PermissionStatus.granted;
      }
      PermissionStatus status = await Permission.locationWhenInUse.request();
      _checkPermissionStatus();
    }catch( e ){
      debugPrint( e.toString() );
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    dynamic screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
            'assets/logo-black.png',
          width: screenWidth*0.9,
        ),
      ),
    );
    // return Scaffold(
    //   backgroundColor: Colors.white,
    //   appBar: (!isChecking ) ? AppBar(
    //     backgroundColor: myColors.appSecBgColor!,
    //     leading: Container(),
    //     title: Text(LanguageNotifier.of(context)!.translate('permissions'), style: TextStyle( color: myColors.appSecTextColor!),),
    //     centerTitle: true,
    //   ) : AppBar(
    //       backgroundColor: myColors.appSecBgColor!
    //   ),
    //   body: ( !isChecking ) ? Center(
    //     child: Padding(
    //       padding: const EdgeInsets.all(20.0),
    //       child: Column(
    //         mainAxisAlignment: MainAxisAlignment.start,
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [
    //           Container(
    //             padding: const EdgeInsets.all(10),
    //             decoration: BoxDecoration(
    //               color: myColors.appSecBgColor,
    //               borderRadius: const BorderRadius.only(
    //                     topLeft: Radius.circular(10),
    //                     topRight: Radius.circular(10),
    //                     bottomLeft: Radius.circular(10),
    //                     bottomRight: Radius.circular(10)
    //               ),
    //               boxShadow: [
    //                 BoxShadow(
    //                   color: Colors.grey.withOpacity(0.3),
    //                   spreadRadius: 3,
    //                   blurRadius: 5,
    //                   offset: const Offset(0, 1), // changes position of shadow
    //                 ),
    //               ]
    //             ),
    //             child: Column(
    //               mainAxisAlignment: MainAxisAlignment.start,
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: [
    //                 Text(LanguageNotifier.of(context)!.translate('location_permissions'), style: TextStyle( fontSize: 16.0, fontWeight: FontWeight.bold, color: myColors.brandColor ),),
    //                 const SizedBox( height: 10.0, ),
    //                 Row(
    //                   mainAxisAlignment: MainAxisAlignment.start,
    //                   crossAxisAlignment: CrossAxisAlignment.start,
    //                   mainAxisSize: MainAxisSize.max,
    //                   children: [
    //                     locationPermissionStatus.isPermanentlyDenied ?
    //                     Flexible(child: Text(LanguageNotifier.of(context)!.translate('error_location'))) :
    //                     locationPermissionStatus.isGranted ?
    //                     Row(
    //                       children: [
    //                         const Icon(Icons.check),
    //                         const SizedBox(width: 10.0,),
    //                         Text( LanguageNotifier.of(context)!.translate('success_location_granted') )
    //                       ],
    //                     ) :
    //                     FilledButton(
    //                       onPressed: _requestPermission,
    //                       child: Text(LanguageNotifier.of(context)!.translate('request_location')),
    //                     )
    //                   ],
    //                 ),
    //               ],
    //             ),
    //           ),
    //           const SizedBox( height: 20.0, ),
    //           Container(
    //             padding: const EdgeInsets.all(10),
    //             decoration: BoxDecoration(
    //                 color: myColors.appSecBgColor,
    //                 borderRadius: const BorderRadius.only(
    //                     topLeft: Radius.circular(10),
    //                     topRight: Radius.circular(10),
    //                     bottomLeft: Radius.circular(10),
    //                     bottomRight: Radius.circular(10)
    //                 ),
    //                 boxShadow: [
    //                   BoxShadow(
    //                     color: Colors.grey.withOpacity(0.3),
    //                     spreadRadius: 3,
    //                     blurRadius: 5,
    //                     offset: const Offset(0, 1), // changes position of shadow
    //                   ),
    //                 ]
    //             ),
    //             child: Column(
    //               mainAxisAlignment: MainAxisAlignment.start,
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: [
    //                 Text(LanguageNotifier.of(context)!.translate('notification_permissions'), style: TextStyle( fontSize: 16.0, fontWeight: FontWeight.bold, color: myColors.brandColor ),),
    //                 const SizedBox( height: 10.0, ),
    //                 Row(
    //                   mainAxisAlignment: MainAxisAlignment.start,
    //                   crossAxisAlignment: CrossAxisAlignment.start,
    //                   mainAxisSize: MainAxisSize.max,
    //                   children: [
    //                     notificationPermissionStatus.isDenied ?
    //                     Flexible(child: Text(LanguageNotifier.of(context)!.translate('error_notification'))) :
    //                     notificationPermissionStatus.isGranted ?
    //                     Row(
    //                       children: [
    //                         const Icon(Icons.check),
    //                         const SizedBox(width: 10.0,),
    //                         Text( LanguageNotifier.of(context)!.translate('success_notification_granted') )
    //                       ],
    //                     ) : Container()
    //                   ],
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ],
    //       ),
    //     ),
    //   ) : Container(),
    // );
  }
}
