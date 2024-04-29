import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/widgets/userAvatar.dart';
import 'package:radius_app/services/userManager.dart';

class LocationPermissionAlert extends StatefulWidget {
  final void Function(String) onAction;
  dynamic user;

  LocationPermissionAlert({Key? key, required this.onAction, required this.user}) : super(key: key);

  @override
  State<LocationPermissionAlert> createState() => _LocationPermissionAlertState();
}

class _LocationPermissionAlertState extends State<LocationPermissionAlert> {
  UserManager userManager = UserManager();
  dynamic currentUser;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    currentUser = widget.user;
  }

  void askLocationPermission(){
    String username = currentUser['username'];
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    showCupertinoDialog(
        context: context,
        builder: (context) {
          // Get the screen width
          double screenWidth = MediaQuery.of(context).size.width;
          double screenHeight = MediaQuery.of(context).size.height;

          return SafeArea(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: screenWidth * 0.9,
                    height: screenHeight * 0.8,
                    color: myColors.brandColor,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox.expand(
                            child: Image.asset('assets/alert_img.png', width: screenWidth*0.9, fit: BoxFit.cover,),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                              child: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('${LanguageNotifier.of(context)!.translate('hello')} $username', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                                      ),
                                      (currentUser['avatar_type'] == 'network') ?
                                      UserAvatar(
                                          url: userManager.getServerUrl('/')
                                              .toString() +
                                              currentUser['avatar_url'],
                                          type: 'network',
                                          radius: 40)
                                          : UserAvatar(
                                          url: currentUser['avatar_url'],
                                          type: 'avatar',
                                          radius: 40)
                                    ],
                                  )
                              )
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              child: Text(LanguageNotifier.of(context)!.translate('location_request_msg'), style: const TextStyle(fontSize: 18, color: Colors.white),),

                            ),
                          ),
                        ),
                        Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: (){
                                      widget.onAction( 'true' );
                                      Navigator.pop(context);
                                    },
                                    child: Text(LanguageNotifier.of(context)!.translate('not_allow_location'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),),
                                  ),
                                  const SizedBox(width: 20,),
                                  FilledButton(
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all<Color>(Colors.white.withOpacity(0.2)),
                                      shape: MaterialStateProperty.all<OutlinedBorder>(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20), // Set the border radius here
                                        ),
                                      ),
                                    ),
                                    onPressed: (){
                                      StorageManager.saveData('app-opened', false);
                                      widget.onAction( 'false' );
                                      Navigator.pop(context);
                                    },
                                    child: Text(LanguageNotifier.of(context)!.translate('share_location'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),),
                                  ),
                                ],
                              ),
                            )
                        )
                      ],
                    ),
                    // child: CupertinoAlertDialog(
                    //     content: Text(
                    //       'Hello $username,\n${LanguageNotifier.of(context)!.translate('location_request_msg')}', textAlign: TextAlign.start,
                    //     ),
                    //     actions: <Widget>[
                    //       /// CASE : YES
                    //       CupertinoDialogAction(
                    //         child: Text(LanguageNotifier.of(context)!.translate('share'),style: TextStyle(color: myColors.brandColor!)),
                    //         onPressed: () async {
                    //           /// GET CURRENT/LOGGED-IN USER ID
                    //           String uid = currentUser['uid'];
                    //         },
                    //       ),
                    //       /// CASE : NO
                    //       CupertinoDialogAction(
                    //         child: Text(LanguageNotifier.of(context)!.translate('cancel'),style: const TextStyle(color: Colors.red),),
                    //         onPressed: () {
                    //           /// CLOSE CONFIRMATION DIALOG
                    //           Navigator.of(context).pop();
                    //         },
                    //       ),
                    //     ]
                    // ),
                  ),
                ),
              ),
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    String username = currentUser['username'];
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: screenWidth * 0.9,
              height: screenHeight * 0.8,
              color: myColors.brandColor,
              child: Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox.expand(
                      child: Image.asset('assets/alert_img.png', width: screenWidth*0.9, fit: BoxFit.cover,),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                        child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${LanguageNotifier.of(context)!.translate('hello')} $username', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                                ),
                                (currentUser['avatar_type'] == 'network') ?
                                UserAvatar(
                                    url: userManager.getServerUrl('/')
                                        .toString() +
                                        currentUser['avatar_url'],
                                    type: 'network',
                                    radius: 40)
                                    : UserAvatar(
                                    url: currentUser['avatar_url'],
                                    type: 'avatar',
                                    radius: 40)
                              ],
                            )
                        )
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        child: Text(LanguageNotifier.of(context)!.translate('location_request_msg'), style: const TextStyle(fontSize: 18, color: Colors.white),),

                      ),
                    ),
                  ),
                  Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: (){
                                widget.onAction( 'true' );
                                Navigator.pop(context);
                              },
                              child: Text(LanguageNotifier.of(context)!.translate('not_allow_location'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),),
                            ),
                            const SizedBox(width: 20,),
                            FilledButton(
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all<Color>(Colors.white.withOpacity(0.2)),
                                shape: MaterialStateProperty.all<OutlinedBorder>(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20), // Set the border radius here
                                  ),
                                ),
                              ),
                              onPressed: (){
                                StorageManager.saveData('app-opened', false);
                                widget.onAction( 'false' );
                                Navigator.pop(context);
                              },
                              child: Text(LanguageNotifier.of(context)!.translate('share_location'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),),
                            ),
                          ],
                        ),
                      )
                  )
                ],
              ),
              // child: CupertinoAlertDialog(
              //     content: Text(
              //       'Hello $username,\n${LanguageNotifier.of(context)!.translate('location_request_msg')}', textAlign: TextAlign.start,
              //     ),
              //     actions: <Widget>[
              //       /// CASE : YES
              //       CupertinoDialogAction(
              //         child: Text(LanguageNotifier.of(context)!.translate('share'),style: TextStyle(color: myColors.brandColor!)),
              //         onPressed: () async {
              //           /// GET CURRENT/LOGGED-IN USER ID
              //           String uid = currentUser['uid'];
              //         },
              //       ),
              //       /// CASE : NO
              //       CupertinoDialogAction(
              //         child: Text(LanguageNotifier.of(context)!.translate('cancel'),style: const TextStyle(color: Colors.red),),
              //         onPressed: () {
              //           /// CLOSE CONFIRMATION DIALOG
              //           Navigator.of(context).pop();
              //         },
              //       ),
              //     ]
              // ),
            ),
          ),
        ),
      ),
    );
  }
}
