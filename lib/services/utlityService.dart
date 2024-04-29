import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/locationManager.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/singleton/socket_singleton.dart';
import '../widgets/userAvatar.dart';
import 'languageManager.dart';
import 'dart:typed_data';



class UtilityService{
  UserManager userManager = UserManager();

  fromUTCtoLocal( dynamic date ){
    print(date);

    DateTime today = DateTime.now().toUtc();
    DateTime dateTime = DateTime.parse( date );

    if( DateFormat("yyyy-MM-dd").format(today) == DateFormat("yyyy-MM-dd").format(today) ){
      dateTime = dateTime.add(DateTime.parse( date ).timeZoneOffset);
      return DateFormat("h:mm a").format(dateTime.toLocal());
    }else{
      dateTime = dateTime.add(DateTime.parse( date ).timeZoneOffset);
      return DateFormat("yyyy-MM-dd h:mm a").format(dateTime.toLocal());
    }
    // print(DateFormat("yyyy-MM-dd").format(today));
    // DateTime dateTime = DateTime.parse( date );

    print( DateFormat("yyyy-MM-dd h:mm a").format(dateTime) );
    print( DateFormat("yyyy-mm-ddThh:mm:ssz").parse(date).toLocal() );
    //print( DateTime.now().toUtc() );.
    // yyyy-mm-ddThh:mm:ss

    return date;
  }

  String getStoryTime( dynamic date ){
    DateTime today = DateTime.now().toUtc();
    DateTime dateTime = DateTime.parse( date );

    if( DateFormat("yyyy-MM-dd").format(today) == DateFormat("yyyy-MM-dd").format(today) ){
      dateTime = dateTime.add(DateTime.parse( date ).timeZoneOffset);
      return DateFormat("h:mm a").format(dateTime.toLocal());
    }else{
      dateTime = dateTime.add(DateTime.parse( date ).timeZoneOffset);
      return DateFormat("yyyy-MM-dd h:mm a").format(dateTime.toLocal());
    }
  }

  String getTextSentDateTime( dynamic date ){
    DateTime today = DateTime.now().toUtc();
    DateTime dateTime = DateTime.parse( date );
    DateTime sentDateTime = dateTime.add( dateTime.timeZoneOffset );
    sentDateTime = sentDateTime.toLocal();

    String sentTime = DateFormat("h:mm a").format(sentDateTime);
    String sentDate = DateFormat("yyyy-MM-dd").format(sentDateTime);

    if( DateFormat("yyyy-MM-dd").format(dateTime) == DateFormat("yyyy-MM-dd").format(today) ){
      return sentTime;
    }else{
      return '$sentDate $sentTime';
    }
  }
  
  double calculateDistanceInMeters(lat1, lon1, lat2, lon2){
    var p = 0.017453292519943295;
    var a = 0.5 - cos((lat2 - lat1) * p)/2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p))/2;
    double distanceInKm = 12742 * asin(sqrt(a));
    return distanceInKm * 1000;
  }

  Future<dynamic> getSettingsFromDb() async{
    try{
      final response = await http.post( getServerUrl( 'settings/get' ) , body: {
        'type' : 'settings',
      });
      dynamic output = json.decode( response.body );
      if( response.statusCode == 200 ){
        return { "status" : true, "settings" : output['settings'] };
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

  Widget showAlertDialog( String text, BuildContext context, void Function(void Function()) callback ){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: myColors.appSecBgColor,
            boxShadow:  [
              BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 10),
            ],
          ),
          width: MediaQuery.of(context).size.width * 1,
          height: MediaQuery.of(context).size.height * 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 82, color: myColors.brandColor!),
              const SizedBox(height: 10,),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(LanguageNotifier.of(context)!.translate('locationError'), textAlign: TextAlign.center ,style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),),
              ),
              const SizedBox(height: 10,),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(LanguageNotifier.of(context)!.translate('locationErrorMsg'), textAlign: TextAlign.center  ,style: const TextStyle(fontSize: 16),),
              ),
              const SizedBox(height: 40,),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: FilledButton(onPressed: (){ Geolocator.openLocationSettings(); }, child: Text(LanguageNotifier.of(context)!.translate('go_to_settings'),) ),
              ),
              const SizedBox(height: 0,),
              TextButton(
                  onPressed: (){
                    callback(() {});
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: myColors.brandColor),
                      const SizedBox(width: 5,),
                      Text( LanguageNotifier.of(context)!.translate('reload'), style: TextStyle(color: myColors.brandColor) ),
                    ],
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget showLoader( String text, BuildContext context ){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: screenWidth,
          height: screenHeight,
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: CircularProgressIndicator( color: myColors.brandColor,),
          ),
        ),
      ),
    );
  }

  Widget showLocationAlertDialog( BuildContext context, dynamic currentUser, void Function() callback, { String type = 'consent', bool privacyDisabled = false } ){
    if( currentUser == null ){
      return Container();
    }

    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    String username = currentUser['username'];
    bool isChecked = false;
    bool hidePrivacyPopup = privacyDisabled;

    Color getColor(Set<MaterialState> states) {
      const Set<MaterialState> interactiveStates = <MaterialState>{
        MaterialState.pressed,
        MaterialState.hovered,
        MaterialState.focused,
      };
      if (states.any(interactiveStates.contains)) {
        return myColors.brandColor!;
      }
      return myColors.brandColor!;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StatefulBuilder(
        builder: (context, setState){

          return Stack(
            children: [
              Positioned.fill(child: Center(
                child: Container(
                  margin: EdgeInsets.only(top: screenHeight*0.06),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius:1,
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: screenWidth,
                      height: screenHeight*0.94,
                      color: Colors.black,
                      child: Column(
                        children: [
                          Center(
                              child: Container(
                                  height: 80,
                                  color: myColors.appSecBgColor,
                                  // padding: const EdgeInsets.all(15),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                          child: Padding(
                                            padding: const EdgeInsets.all(15),
                                            child: Row(
                                              children: [
                                                /// USER AVATAR
                                                (currentUser['avatar_type'] == 'network') ? UserAvatar(
                                                    url: userManager.getServerUrl('/')
                                                        .toString() +
                                                        currentUser['avatar_url'],
                                                    type: 'network',
                                                    radius: 40)
                                                    : UserAvatar(
                                                    url: currentUser['avatar_url'],
                                                    type: 'avatar',
                                                    radius: 40
                                                ),
                                                /// USER Full NAME
                                                Expanded(
                                                  child: Text('${LanguageNotifier.of(context)!.translate('hello')} $username', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: myColors.appSecTextColor),),
                                                ),
                                        ],
                                      ),
                                          )
                                      ),
                                      Positioned(
                                        top: 0,
                                          right: (LanguageNotifier.of(context)!.translate('lang') == 'en') ? 0 : (screenWidth*0.82),
                                          child: /// CLOSE ALERT BUTTON
                                          Container(
                                            height: 80,
                                            width: 80,
                                            padding: EdgeInsets.all(5),
                                            color: const Color(0XFFD9D9D9),
                                            child: IconButton(
                                                onPressed: () {
                                                  showConfirmationAlert(context, callback);
                                                }, icon: const Icon(Icons.clear, size: 32, color: Colors.black,)),
                                          )
                                      )
                                    ],
                                  )
                              )
                          ),
                          // BANNER
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Stack(
                                children: [
                                  // BANNER IMAGE
                                  Positioned.fill(
                                      child: SizedBox.expand(
                                        child: Image.asset('assets/alert_bg_img.jpg', width: screenWidth*0.9, fit: BoxFit.cover,),
                                      )
                                  ),
                                  // BANNER TEXT
                                  // Positioned(
                                  //   bottom: 0,
                                  //   left: screenWidth*0.05,
                                  //   child: Container(
                                  //     width: screenWidth*0.9,
                                  //     padding: const EdgeInsets.symmetric(vertical: 20),
                                  //     child: Text(
                                  //       LanguageNotifier.of(context)!.translate('loc_nav_title'),
                                  //       style: const TextStyle(
                                  //           fontSize: 18,
                                  //           color: Colors.white,
                                  //           fontWeight:
                                  //           FontWeight.w600
                                  //       ), textAlign:
                                  //       TextAlign.center,
                                  //     ),
                                  //   )
                                  // )
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              child: Container(
                                color: Colors.black,
                                // padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                                      color: Colors.black,
                                      child: Column(
                                        children: [
                                          // Center(
                                          //   child: Image.asset('assets/location-icon.png'),
                                          // ),
                                          // SizedBox(height: 20,),
                                          (LanguageNotifier.of(context)!.translate('lang') == 'en') ? Image.asset('assets/popup-animate-en.webp') : Image.asset('assets/popup-animate-ar.webp'),
                                        ],
                                      ),
                                    ),
                                    // Container(
                                    //   padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 15),
                                    //   color: myColors.appSecBgColor,
                                    //   child: Column(
                                    //     mainAxisAlignment: MainAxisAlignment.start,
                                    //     crossAxisAlignment: CrossAxisAlignment.start,
                                    //     children: [
                                    //       Text(LanguageNotifier.of(context)!.translate('loc_nav_list_heading'), textAlign: TextAlign.start, style: TextStyle(color: myColors.brandColor, fontWeight: FontWeight.w600, fontSize: 16),),
                                    //       const SizedBox(height: 10,),
                                    //       Text('\u2022 ${LanguageNotifier.of(context)!.translate('loc_nav_list_item_1')}', textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.w600, color: myColors.appSecTextColor),),
                                    //       const SizedBox(height: 5,),
                                    //       Text('\u2022 ${LanguageNotifier.of(context)!.translate('loc_nav_list_item_2')}', textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.w600, color: myColors.appSecTextColor),),
                                    //       const SizedBox(height: 5,),
                                    //       Text('\u2022 ${LanguageNotifier.of(context)!.translate('loc_nav_list_item_3')}', textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.w600, color: myColors.appSecTextColor),)
                                    //     ],
                                    //   ),
                                    // ),

                                    Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Container(
                                        width: screenWidth,
                                        decoration: BoxDecoration(
                                            color: const Color(0XFFD9D9D9),
                                            borderRadius: BorderRadius.circular(25)
                                          //more than 50% of width makes circle
                                        ),
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
                                              child: Text(LanguageNotifier.of(context)!.translate('loc_nav_list_heading'), textAlign: TextAlign.center, style: TextStyle(color: myColors.brandColor, fontWeight: FontWeight.w600, fontSize: 18),),
                                            ),
                                            const SizedBox(height: 10,),
                                            Padding(
                                              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                                              child: IntrinsicWidth(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Image.asset(
                                                              'assets/logout-icon.png',
                                                              width: 50,
                                                            ),
                                                            const SizedBox(height: 10,),
                                                            Text(LanguageNotifier.of(context)!.translate('loc_nav_list_item_1'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black, fontSize: 12),),
                                                          ],
                                                        )
                                                    ),
                                                    Expanded(
                                                        child: Column(
                                                          children: [
                                                            Image.asset(
                                                              'assets/close-icon.png',
                                                              width: 50,
                                                            ),
                                                            const SizedBox(height: 10,),
                                                            Text(LanguageNotifier.of(context)!.translate('loc_nav_list_item_2'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black, fontSize: 12),),
                                                          ],
                                                        )
                                                    ),
                                                    Expanded(
                                                        child: Column(
                                                          children: [
                                                            Image.asset(
                                                              'assets/wifi-disable-icon.png',
                                                              width: 50,
                                                            ),
                                                            const SizedBox(height: 10,),
                                                            Text(LanguageNotifier.of(context)!.translate('loc_nav_list_item_3'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black, fontSize: 12),)
                                                          ],
                                                        )
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              width: screenWidth,
                                              decoration: BoxDecoration(
                                                  color: myColors.brandColor,
                                                  borderRadius: BorderRadius.circular(25)
                                                //more than 50% of width makes circle
                                              ),
                                              child: Text(LanguageNotifier.of(context)!.translate('loc_nav_footer'), style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Container(
                                    //   color: Colors.red,
                                    //   height: 100,
                                    //   padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                                    //   child: ,
                                    // ),
                                  ],
                                ),

                              ),
                            ),
                          ),
                          // Container(
                          //   height: 70,
                          //   width: screenWidth,
                          //   color: myColors.brandColor,
                          //   padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                          //   child: Padding(
                          //     padding: const EdgeInsets.symmetric(horizontal: 20),
                          //     child: Text(LanguageNotifier.of(context)!.translate('loc_nav_footer'), style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center,),
                          //   ),
                          // )
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
              )),
              // ( hidePrivacyPopup == true ) ? Positioned(
              //   child: Container(
              //     color: myColors.appSecTextColor!.withOpacity(0.3),
              //     width: screenWidth,
              //     height: screenHeight,
              //   ),
              // ) : Container(),
              // ( hidePrivacyPopup == true ) ? Positioned(
              //     top: (screenHeight*0.5/2)+50,
              //     left: screenWidth*0.1/2,
              //     child: ClipRRect(
              //       borderRadius: BorderRadius.circular(25),
              //       child: Container(
              //         width: screenWidth*0.9,
              //         padding: EdgeInsets.all(25),
              //         decoration: BoxDecoration(
              //           color: myColors.appSecBgColor,
              //           boxShadow: [
              //             BoxShadow(
              //               color: Colors.black.withOpacity(0.5),
              //               spreadRadius:1,
              //               blurRadius: 20,
              //             ),
              //           ],
              //         ),
              //         child: Column(
              //           children: [
              //             Text('Confirming indicates that you understand how to manage your privacy on Radius', style: TextStyle(fontSize: 15),),
              //             Transform.translate(
              //               offset: const Offset(-10, 0),
              //               child: CheckboxListTile(
              //                 contentPadding: EdgeInsets.zero,
              //                 controlAffinity: ListTileControlAffinity.leading,
              //                 title: Transform.translate(
              //                   offset: const Offset(-20, 0),
              //                   child: const Text('Don\'t show me privacy popup again', style: TextStyle(fontSize: 13),),
              //                 ),
              //                 autofocus: false,
              //                 activeColor: myColors.brandColor,
              //                 checkColor: Colors.white,
              //                 selected: false,
              //                 value: isChecked,
              //                 onChanged: (value) {
              //                   setState(() {
              //                     isChecked = value!;
              //                   });
              //                 },
              //               ),
              //             ),
              //             Row(
              //               mainAxisAlignment: MainAxisAlignment.end,
              //               children: [
              //                 OutlinedButton(
              //                   onPressed: (){
              //                     Provider.of<LocationManager>(context, listen: false).setPrivacyStatus( true );
              //                     setState( () => {
              //                       hidePrivacyPopup = true
              //                     } );
              //                   },
              //                   child: const Text('Cancel', style: TextStyle(color: Color(0XFFB50D0D)),),
              //                   style: OutlinedButton.styleFrom(
              //                     side: const BorderSide(width: 1.0, color: Color(0XFFB50D0D)),
              //                     shape: RoundedRectangleBorder(
              //                       borderRadius: BorderRadius.circular(20.0),
              //                     ),
              //                   ),
              //                 ),
              //                 const SizedBox(width: 10,),
              //                 FilledButton(
              //                     onPressed: (){
              //                       Provider.of<LocationManager>(context, listen: false).setPrivacyStatus( true );
              //                       setState( () => {
              //                         hidePrivacyPopup = true
              //                       } );
              //                     },
              //                     style: ButtonStyle(
              //                         shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              //                             RoundedRectangleBorder(
              //                                 borderRadius: BorderRadius.circular(20.0),
              //                             )
              //                         )
              //                     ),
              //                     child: Text('Confirm')
              //                 )
              //               ],
              //             )
              //           ],
              //         ),
              //
              //       ),
              //     )
              // ) : Container()
            ],
          );
        },
      ),
    );
    // return Scaffold(
    //   backgroundColor: Colors.transparent,
    //   body: Center(
    //     child: Container(
    //       padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
    //       decoration: BoxDecoration(
    //         borderRadius: BorderRadius.circular(10),
    //         color: myColors.appSecBgColor,
    //         boxShadow:  [
    //           BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 10),
    //         ],
    //       ),
    //       width: MediaQuery.of(context).size.width * 1,
    //       height: MediaQuery.of(context).size.height * 1,
    //       child: Column(
    //         mainAxisSize: MainAxisSize.min,
    //         mainAxisAlignment: MainAxisAlignment.center,
    //         crossAxisAlignment: CrossAxisAlignment.center,
    //         children: [
    //           Icon(Icons.location_on_outlined, size: 82, color: myColors.brandColor!),
    //           const SizedBox(height: 10,),
    //           SizedBox(
    //             width: MediaQuery.of(context).size.width * 0.8,
    //             child: Text(LanguageNotifier.of(context)!.translate('locationError'), textAlign: TextAlign.center ,style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),),
    //           ),
    //           const SizedBox(height: 10,),
    //           SizedBox(
    //             width: MediaQuery.of(context).size.width * 0.8,
    //             child: Text(LanguageNotifier.of(context)!.translate('locationErrorMsg'), textAlign: TextAlign.center  ,style: const TextStyle(fontSize: 16),),
    //           ),
    //           const SizedBox(height: 40,),
    //           SizedBox(
    //             width: MediaQuery.of(context).size.width * 0.7,
    //             child: FilledButton(onPressed: (){ Geolocator.openLocationSettings(); }, child: Text(LanguageNotifier.of(context)!.translate('go_to_settings'),) ),
    //           ),
    //           const SizedBox(height: 0,),
    //           TextButton(
    //               onPressed: (){
    //                 callback(() {});
    //               },
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 children: [
    //                   Icon(Icons.refresh, color: myColors.brandColor),
    //                   const SizedBox(width: 5,),
    //                   Text( LanguageNotifier.of(context)!.translate('reload'), style: TextStyle(color: myColors.brandColor) ),
    //                 ],
    //               )
    //           ),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }

  void showConfirmationAlert( BuildContext context, void Function() callback ){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    bool isChecked = false;

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0))),
              contentPadding: EdgeInsets.all(25),
              content: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(LanguageNotifier.of(context)!.translate('loc_nav_confirmation_msg'), style: const TextStyle(fontSize: 15),),
                      Transform.translate(
                        offset: (LanguageNotifier.of(context)!.translate('lang') == 'en') ? const Offset(-10, 0) : const Offset(10, 0),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Transform.translate(
                            offset: (LanguageNotifier.of(context)!.translate('lang') == 'en') ? const Offset(-20, 0) : const Offset(20, 0),
                            child: Text(LanguageNotifier.of(context)!.translate('loc_nav_confirmation_check'), style: const TextStyle(fontSize: 13),),
                          ),
                          autofocus: false,
                          activeColor: myColors.brandColor,
                          checkColor: Colors.white,
                          selected: false,
                          value: isChecked,
                          onChanged: (value) {
                            setState(() {
                              isChecked = value!;
                            });
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: (){
                              // Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
                              // Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( true );
                              // callback();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(width: 1.0, color: Color(0XFFB50D0D)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                            child: Text(LanguageNotifier.of(context)!.translate('cancel'), style: const TextStyle(color: Color(0XFFB50D0D)),),
                          ),
                          const SizedBox(width: 10,),
                          FilledButton(
                              onPressed: (){
                                Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
                                Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( true );
                                callback();
                                Navigator.of(context).pop();
                                // Provider.of<LocationManager>(context, listen: false).setPrivacyStatus( true );
                              },
                              style: ButtonStyle(
                                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20.0),
                                      )
                                  )
                              ),
                              child: Text(LanguageNotifier.of(context)!.translate('confirm'))
                          )
                        ],
                      )
                    ],
                  );
                }
              )
          );
        }
    );
  }

  Widget showDisconnectDialog( String text, BuildContext context, void Function(void Function()) callback ){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: myColors.appSecBgColor,
            boxShadow:  [
              BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 10),
            ],
          ),
          width: MediaQuery.of(context).size.width * 0.7,
          //height: MediaQuery.of(context).size.height * 1,
          height: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon(Icons.wifi_off, size: 82, color: myColors.brandColor!,),
              // const SizedBox(height: 10,),
              // Text(LanguageNotifier.of(context)!.translate('offline_text'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              // const SizedBox(height: 10,),
              // Text(
              //   LanguageNotifier.of(context)!.translate('offline_hint'),
              //   style: const TextStyle(fontSize: 16,),
              //   textAlign: TextAlign.center,
              // ),
              // const SizedBox(height: 40,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: myColors!.brandColor,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(LanguageNotifier.of(context)!
                      .translate('reconnecting'), style: const TextStyle(fontSize: 16,))
                ],
              ),
              // const SizedBox( height: 20,),
              // FilledButton(
              //     onPressed: (){
              //       callback( () => {} );
              //     },
              //     child: Row(
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         Icon(Icons.refresh),
              //         const SizedBox(width: 5,),
              //         Text(LanguageNotifier.of(context)!.translate('reload'),),
              //       ],
              //     )
              // ),
            ],
          ),
        ),
      ),
    );
  }


  Widget handleCustomAlerts(
      {
        required BuildContext context,
        required dynamic user,
        required SocketSingleton ss,
        required void Function() callback,
        required void Function(void Function()) setState,
        required bool privacyDisabled,
      } ){

    return Consumer2<PermissionManager, LocationManager>(
        builder: (context, permissionManager, locationManager, child) {

          return (!ss.socket.connected) ?  showDisconnectDialog(
              '',
              context,
              setState
          ) :
          ( ss.socket.connected && (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? showLocationAlertDialog(
              context,
              user,
              callback,
              type: 'permission',
              privacyDisabled: privacyDisabled
          ) :
          ( ss.socket.connected && !locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? showLocationAlertDialog(
              context,
              user,
              callback,
              privacyDisabled: privacyDisabled
          ) : Container();
        }
    );
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

  //SANA
  Future<File?> compressAndConvertToFile(File imageFile) async {
    if (imageFile == null) return null;

    // Read the file as a Uint8List (byte data)
    Uint8List imageData = await imageFile.readAsBytes();

    // Set the desired maximum width and height of the compressed image
    int maxWidth = 1080; // Change this to your desired maximum width
    int maxHeight = 1920; // Change this to your desired maximum height

    // Compress the image without losing quality
    Uint8List compressedData = await FlutterImageCompress.compressWithList(
      imageData,
      minHeight: maxHeight,
      minWidth: maxWidth,
    );

    // Get the temporary directory where we'll save the compressed image
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;

    try {
      // Create a temporary file with a unique name and the .jpg extension
      File tempFile = File('$tempPath/${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Write the compressed image data to the temporary file
      await tempFile.writeAsBytes(compressedData);

      return tempFile;
    } catch (e) {
      print('Error while converting Uint8List to File: $e');
      return null;
    }
  }

}