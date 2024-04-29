import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/loaderNotifer.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/locationManager.dart';
import '../widgets/userAvatar.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with WidgetsBindingObserver{
  UserManager userManager = UserManager();
  final SocketSingleton ss = SocketSingleton();
  dynamic currentUser;

  PermissionStatus locationPermissionStatus = PermissionStatus.denied;
  bool isLocationEnabled = false;
  bool isCameraEnabled = false;
  bool isNotificationEnabled = false;
  bool isVisibilityEnabled = true;
  bool isDeletingAccount = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    getUser();
    _checkPermissions();
  }

  Future<void> getUser() async {
    Provider.of<LoaderNotifier>(context, listen: false).setLoader( false );
    final response = await StorageManager.getUser();
    isVisibilityEnabled =  await StorageManager.readData('visibility');
    if (response != null && response['username'] != null && mounted) {
      currentUser = response;
      setState(() {});
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignIn()),
              (Route<dynamic> route) => false);
    }
    if( mounted ){
      setState(() => {});
    }
  }

  void _checkPermissions() async {
    locationPermissionStatus = await Permission.locationWhenInUse.status;
    print(locationPermissionStatus);
    //setState(() {});
  }

  Future<void> _handleAccountDeletion(){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    TextEditingController passwordController = TextEditingController(text: '');

    return showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(LanguageNotifier.of(context)!.translate('delete_account')),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            content: StatefulBuilder(
                builder: (context, setState) {
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(LanguageNotifier.of(context)!.translate('deactivate_msg')),
                        const SizedBox(height: 10,),
                        TextFormField(
                          obscureText: true,
                          keyboardType: TextInputType.text,
                          controller: passwordController,
                          style: const TextStyle(fontSize: 16.0, height: 1.0),
                          decoration: InputDecoration(
                            labelText: LanguageNotifier.of(context)!.translate('password'),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: myColors.borderColor!.withOpacity(0.5)),
                            ),
                            disabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: myColors.borderColor!.withOpacity(0.5)),
                            ),
                            //border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {},
                        ),
                      ],
                    ),
                  );
                }
            ),
            actions: <Widget>[
              (!isDeletingAccount) ? TextButton(
                child: Text(LanguageNotifier.of(context)!.translate('cancel'), style: TextStyle(color: myColors.appSecTextColor), ),
                onPressed: () async {
                  setState(() { isDeletingAccount = false; });
                  Navigator.of(context).pop();
                },
              ) : Container(),
              FilledButton(
                child: (!isDeletingAccount) ? Text(LanguageNotifier.of(context)!.translate('delete') ) : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator( strokeWidth: 2, color: Colors.white,),
                    ),
                    const SizedBox(width: 10,),
                    Text(LanguageNotifier.of(context)!.translate('delete') )
                  ],
                ),
                onPressed: () async {
                  /// GET CURRENT/LOGGED-IN USER ID
                  String uid = currentUser['uid'];

                  if( passwordController.text.trim().isEmpty ){
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LanguageNotifier.of(context)!.translate('error_pass_required')),
                      ),
                    );
                    return;
                  }else{
                    if( isDeletingAccount == false ){
                      /// CHECK IF USER IS CONNECTED TO SOCKET OR NOT & ID IS VALID/NOT-EMPTY
                      if (ss.socket.connected && uid.isNotEmpty) {
                        setState(() { isDeletingAccount = true; });
                        /// DELETE USER ACCOUNT COMPLETELY
                        ss.socket.emitWithAck('deactivate-account',{ "uid": uid, "password" : passwordController.text }, ack: ( response ) async {
                          if( response['status'] == true ){
                            ss.socket.clearListeners();
                            ss.socket.disconnect();
                            ss.socket.dispose();
                            /// DELETE USER INFO FROM LOCAL-STORAGE
                            await StorageManager.deleteUser();
                            setState(() { isDeletingAccount = false; });
                            /// NAVIGATE USER TO LOGIN SCREEN
                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const SignIn()),
                                      (Route<dynamic> route) => false
                              );
                            }
                          }else{
                            setState(() { isDeletingAccount = false; });
                            debugPrint(response['message'].toString());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text( LanguageNotifier.of(context)!.translate('error_incorrect_password') ),
                              ),
                            );
                          }
                        });
                      }else{
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text( 'UID not found' ),
                          ),
                        );
                      }
                    }
                  }
                  //setState(() { isDeletingAccount = true; });
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Consumer3<PermissionManager, LocationManager, LoaderNotifier>(
        builder: (context, permissionManager, locationManager, loader, child) {
          return Stack(
            children: [
              Positioned.fill(
                  child: Scaffold(
                      backgroundColor: myColors.appSecBgColor,
                      appBar: AppBar(
                        backgroundColor: myColors.appSecBgColor,
                        leading: IconButton(
                          color: myColors.appSecTextColor,
                          icon: const Icon(Icons.arrow_back_ios),// set the color of the back button here
                          onPressed: () => Navigator.pop(context),
                        ),
                        centerTitle: true,
                        title: Text(
                          LanguageNotifier.of(context)!.translate('settings'),
                          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16.0,color: myColors.appSecTextColor),
                        ),
                        elevation: 0.2,
                      ),
                      body: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Container(
                            //   padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 5),
                            //   child: Text(
                            //     'Permissions',
                            //     style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16.0,color: myColors.appSecTextColor),
                            //   ),
                            // ),
                            ListTile(
                              title: Text(
                                LanguageNotifier.of(context)!.translate('account_visibility'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0,color: myColors.appSecTextColor),
                              ),
                            ),
                            /// VISIBILITY TOGGLE
                            ListTile(
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: Text(LanguageNotifier.of(context)!.translate('show_visibility'))),
                                  const SizedBox(width: 15.0),
                                  FlutterSwitch(
                                      width: 60,
                                      height: 30,
                                      toggleSize: 25.0,
                                      borderRadius: 20.0,
                                      toggleColor: myColors.brandColor!,
                                      switchBorder: Border.all(
                                          width: 1,
                                          color: myColors.borderColor!),
                                      activeColor: Colors.white,
                                      inactiveColor: Colors.white,
                                      value: (locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied) ? true : false,
                                      onToggle: (value) {
                                        if( ss.socket.connected ){
                                          ss.socket.emit('set-user-visibility', { "uid": currentUser['uid'], "status" : value });
                                          StorageManager.saveData('visibility', value);
                                          if( value ){
                                            StorageManager.saveData('location-enabled', true );
                                            StorageManager.saveData('location-denied', false );
                                            Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( false );
                                            Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( true );
                                          }else{
                                            StorageManager.saveData('location-enabled', false );
                                            StorageManager.saveData('location-denied', true );
                                            Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( true );
                                            Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
                                          }
                                          setState(() {
                                            isVisibilityEnabled = value;
                                          });
                                        }
                                      }),
                                ],
                              ),
                            ),
                            // ListTile(
                            //   title: Text(
                            //     'Manage Permissions',
                            //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0,color: myColors.appSecTextColor),
                            //   ),
                            // ),
                            // /// LOCATION PERMISSION TOGGLE
                            // ListTile(
                            //   title: Row(
                            //     mainAxisAlignment: MainAxisAlignment.center,
                            //     crossAxisAlignment: CrossAxisAlignment.center,
                            //     children: [
                            //       Expanded(child: Text('Location Permission')),
                            //       const SizedBox(width: 15.0),
                            //       (!locationPermissionStatus.isDenied) ? FlutterSwitch(
                            //           width: 60,
                            //           height: 30,
                            //           toggleSize: 25.0,
                            //           borderRadius: 20.0,
                            //           toggleColor: myColors.brandColor!,
                            //           switchBorder: Border.all(
                            //               width: 1,
                            //               color: myColors.borderColor!),
                            //           activeColor: Colors.white,
                            //           inactiveColor: Colors.white,
                            //           value: ( locationPermissionStatus.isGranted ) ? true : false,
                            //           onToggle: (value) {
                            //             _handleLocationToggle(value);
                            //           }) : const Text('Denied'),
                            //     ],
                            //   ),
                            // ),
                            // /// NOTIFICATION PERMISSION TOGGLE
                            // ListTile(
                            //   title: Row(
                            //     mainAxisAlignment: MainAxisAlignment.center,
                            //     crossAxisAlignment: CrossAxisAlignment.center,
                            //     children: [
                            //       Expanded(child: Text('Notification Permission')),
                            //       const SizedBox(width: 15.0),
                            //       FlutterSwitch(
                            //           width: 60,
                            //           height: 30,
                            //           toggleSize: 25.0,
                            //           borderRadius: 20.0,
                            //           toggleColor: myColors.brandColor!,
                            //           switchBorder: Border.all(
                            //               width: 1,
                            //               color: myColors.borderColor!),
                            //           activeColor: Colors.white,
                            //           inactiveColor: Colors.white,
                            //           value: isNotificationEnabled,
                            //           onToggle: (value) {
                            //             // if (value) {
                            //             //   widget.theme.setLightMode();
                            //             // } else {
                            //             //   widget.theme.setDarkMode();
                            //             // }
                            //           }),
                            //     ],
                            //   ),
                            // ),
                            // /// CAMERA PERMISSION TOGGLE
                            // ListTile(
                            //   title: Row(
                            //     mainAxisAlignment: MainAxisAlignment.center,
                            //     crossAxisAlignment: CrossAxisAlignment.center,
                            //     children: [
                            //       Expanded(child: Text('Camera Permission')),
                            //       const SizedBox(width: 15.0),
                            //       FlutterSwitch(
                            //           width: 60,
                            //           height: 30,
                            //           toggleSize: 25.0,
                            //           borderRadius: 20.0,
                            //           toggleColor: myColors.brandColor!,
                            //           switchBorder: Border.all(
                            //               width: 1,
                            //               color: myColors.borderColor!),
                            //           activeColor: Colors.white,
                            //           inactiveColor: Colors.white,
                            //           value: isCameraEnabled,
                            //           onToggle: (value) {
                            //             // if (value) {
                            //             //   widget.theme.setLightMode();
                            //             // } else {
                            //             //   widget.theme.setDarkMode();
                            //             // }
                            //           }),
                            //     ],
                            //   ),
                            // ),
                            ListTile(
                              title: Text(
                                LanguageNotifier.of(context)!.translate('manage_account'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0,color: myColors.appSecTextColor),
                              ),
                            ),
                            /// DEACTIVATE
                            ListTile(
                              title: Row(
                                children: <Widget>[
                                  const Icon(Icons.lock_open_outlined,),
                                  const SizedBox(width: 15.0),
                                  Text(LanguageNotifier.of(context)!.translate('change_password')),
                                ],
                              ),
                              onTap: () => Navigator.pushNamed(context, '/change-password'),
                            ),
                            ListTile(
                              title: Row(
                                children: <Widget>[
                                  const Icon(Icons.delete_outline_outlined, color: Colors.red,),
                                  const SizedBox(width: 15.0),
                                  Text(LanguageNotifier.of(context)!.translate('delete_account'), style: const TextStyle(color: Colors.red),),
                                ],
                              ),
                              onTap: () async {
                                _handleAccountDeletion();
                                /// Confirmation dialog to confirm if user want to delete his/her account.
                                // showCupertinoDialog(
                                //     context: context,
                                //     builder: (context) =>
                                //         CupertinoAlertDialog(
                                //             title: Text(LanguageNotifier.of(context)!.translate('deactivate')),
                                //             content: Text(LanguageNotifier.of(context)!.translate('deactivate_msg')),
                                //             actions: <Widget>[
                                //               /// CASE : YES
                                //               CupertinoDialogAction(
                                //                 child: Text(LanguageNotifier.of(context)!.translate('yes'),style: TextStyle(color: myColors.brandColor!)),
                                //                 onPressed: () async {
                                //                   _handleAccountDeletion();
                                //                   /// GET CURRENT/LOGGED-IN USER ID
                                //                   String uid = currentUser['uid'];
                                //                   /// CHECK IF USER IS CONNECTED TO SOCKET OR NOT & ID IS VALID/NOT-EMPTY
                                //                   if (ss.socket.connected && uid.isNotEmpty) {
                                //                     Provider.of<LoaderNotifier>(context, listen: false).setLoader( true );
                                //                     /// DELETE USER ACCOUNT COMPLETELY
                                //                     ss.socket.emitWithAck('deactivate-account',{ "uid": uid}, ack: ( response ) async {
                                //                       if( response['status'] == true ){
                                //                         ss.socket.clearListeners();
                                //                         ss.socket.disconnect();
                                //                         ss.socket.dispose();
                                //                         /// DELETE USER INFO FROM LOCAL-STORAGE
                                //                         await StorageManager.deleteUser();
                                //                         /// NAVIGATE USER TO LOGIN SCREEN
                                //                         if (mounted) {
                                //                           Provider.of<LoaderNotifier>(context, listen: false).setLoader( false );
                                //                           Navigator.of(context).pushAndRemoveUntil(
                                //                               MaterialPageRoute(builder: (context) => const SignIn()),
                                //                                   (Route<dynamic> route) => false
                                //                           );
                                //                         }
                                //                       }else{
                                //                         Provider.of<LoaderNotifier>(context, listen: false).setLoader( false );
                                //                         ScaffoldMessenger.of(context).showSnackBar(
                                //                           SnackBar(
                                //                             content: Text( response['message'] ),
                                //                           ),
                                //                         );
                                //                       }
                                //                     });
                                //                   }else{
                                //                     ScaffoldMessenger.of(context).showSnackBar(
                                //                       const SnackBar(
                                //                         content: Text( 'UID not found' ),
                                //                       ),
                                //                     );
                                //                   }
                                //                 },
                                //               ),
                                //               /// CASE : NO
                                //               CupertinoDialogAction(
                                //                 child: Text(LanguageNotifier.of(context)!.translate('no'),style: const TextStyle(color: Colors.red),),
                                //                 onPressed: () {
                                //                   /// CLOSE CONFIRMATION DIALOG
                                //                   Navigator.of(context).pop();
                                //                 },
                                //               ),
                                //             ]
                                //         )
                                // );
                              },
                            ),
                          ],
                        ),
                      )
                  )
              ),
              ( loader.isLoading ) ? Positioned(
                  child: UtilityService().showLoader(
                      'Updating',
                      context,
                  )
              ) :
              ( (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? Positioned(
                  child: UtilityService().showLocationAlertDialog(
                      context,
                      currentUser,
                      _checkPermissions,
                      type: 'permission',
                      privacyDisabled: locationManager.isPrivacyDisabled
                  )
              ) :
              ( !locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? UtilityService().showLocationAlertDialog(
              context,
              currentUser,
              _checkPermissions,
              privacyDisabled: locationManager.isPrivacyDisabled
              ) : Container(),
            ],
          );
        }
    );
  }
}
