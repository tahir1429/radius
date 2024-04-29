import 'package:flutter/material.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:radius_app/services/userManager.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  UtilityService utilityService = UtilityService();
  UserManager userManager = UserManager();
  String route = '/permissions';

  @override
  void initState() {
    super.initState();
    getSettings();
  }

  void getSettings() async {
    final dynamic response = await utilityService.getSettingsFromDb();
    int radius = 100;
    if( response['status'] && response['settings'] != null ){
      final settings = response['settings']['setting'];
      /// RADIUS
      radius = settings['radius'] ?? radius;
      /// SMTP EMAIL
      String email = ( settings['smtpEmail'] != null && settings['smtpEmail'] != '' ) ? settings['smtpEmail'] : '';
      if( email.isNotEmpty ){
        StorageManager.saveData('smtpEmail', email );
      }
      /// SMTP PASSWORD
      String pass = ( settings['smtpPass'] != null && settings['smtpPass'] != '' ) ? settings['smtpPass'] : '';
      if( pass.isNotEmpty ){
        StorageManager.saveData('smtpPass', pass );
      }
    }
    StorageManager.saveData('radius', radius.toDouble() );
    // SET APP-STATE TO OPENED
    StorageManager.saveData('app-opened', true );
    StorageManager.saveData('location-enabled', false );
    StorageManager.saveData('location-denied', false );
    StorageManager.saveData('privacy-disabled', false );
    // CHECK PERMISSIONS
    _checkPermissionStatus();
  }

  Future<void> goTo() async {
    await Future.delayed(const Duration(seconds: 2), (){
      Navigator.pushReplacementNamed(context, route, arguments: {
        'status' : true,
      });
    });
  }

  Future<void> _checkPermissionStatus() async {
    try{
      final status = await Permission.locationWhenInUse.status;
      final isLoggedIn = await userManager.isLoggedIn();
      if( isLoggedIn  && mounted ){
        if( status.isGranted ){
          final user = await StorageManager.getUser();
          dynamic isExist = await userManager.getUserByEmail( user['email'] );
          if( isExist['status'] == false ){
            await StorageManager.deleteUser();
            Navigator.of(context)
                .pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (
                        context) => const SignIn()),
                    (Route<
                    dynamic> route) => false);
          }
          else if( user['username'] == null || user['username'] == '' ){
            route = '/setup-avatar';
          }else{
            route = '/home';
          }
        }
      }
    }catch( e ){
      debugPrint( e.toString() );
    }
    if( mounted ){
      goTo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Scaffold(
      backgroundColor: myColors.appSecBgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/logo-black.png',
              width: MediaQuery.of(context).size.width*0.7,
              repeat: ImageRepeat.noRepeat,
              alignment: Alignment.center,
              color: myColors.appSecTextColor,
            ),
          ],
        ),
      ),
    );
  }
}
