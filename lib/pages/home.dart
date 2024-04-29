import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/services/locationManager.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/widgets/empty-map.dart';
import 'package:radius_app/widgets/map.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/pages/chat.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:badges/badges.dart' as badges;
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:radius_app/widgets/userAvatar.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin, WidgetsBindingObserver {
  UserManager userManager = UserManager();
  Map data = {};
  late final _tabController = TabController(length: 2, vsync: this);
  late final _pageTabController = TabController(length: 3, vsync: this);
  late final PageController _pageController = PageController( initialPage: 1);
  dynamic currentUser;
  List<Object?> nearbyUsers = [];
  bool isFindingPeople = false;
  Timer? timer;
  double radiusInMeters = 100.0;
  dynamic position;
  int chatCounter = 0;
  final SocketSingleton ss = SocketSingleton();
  final double swipeThreshold = 50; // Adjust this value as needed
  double? _dragStartPositionX;
  double? _dragCurrentPositionX;
  bool isSwipingFromEdge = false;
  int pageViewIndex = 0;

  bool isLocationServiceEnabled = false;
  PermissionStatus locationStatus = PermissionStatus.denied;
  bool isLocationDenied = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    // TODO: implement initState
    super.initState();
    getLoggedInUser();
    timer = Timer.periodic(const Duration(seconds: 10), (Timer t) => _getCurrentLocation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _getCurrentLocation();
        getChatCounter();
        debugPrint("app in resumed in home");
        break;
      case AppLifecycleState.inactive:
        debugPrint("app in inactive in home");
        break;
      case AppLifecycleState.paused:
        debugPrint("app in paused in home");
        break;
      case AppLifecycleState.detached:
        debugPrint("app in detached in home");
        break;
    }
  }

  /// REQUEST FCM (NOTIFICATION) TOKEN PERMISSION
  void getFcmTokenAndPermission() async {
    try{
      // if( currentUser['fcmToken'] != null && currentUser['fcmToken'] != '' ){
      //   return;
      // }
      final messaging = FirebaseMessaging.instance;
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
        // For Android Device
        if( Platform.isAndroid ){
          // Get Token
          String? token = await messaging.getToken();
          StorageManager.saveData('notification-token', token );
          updateFcmToken();
        }
        // For IOS Device
        else if( Platform.isIOS ){
          // Get APNS Token
          String? apnsToken = await messaging.getAPNSToken();
          StorageManager.saveData('notification-apns-token', apnsToken );
          // Get Token
          String? token = await messaging.getToken();
          StorageManager.saveData('notification-token', token );
          updateFcmToken();
        }
      }
    }catch( e ){
      debugPrint( e.toString() );
    }
  }

  /// UPDATE USER FCM (NOTIFICATION) TOKEN
  void updateFcmToken() async {
    final String? token = await StorageManager.readData( 'notification-token' ) ?? '';
    if( token!= null &&  token.isNotEmpty ){
      // Store token if not already stored
      final response = await userManager.updateUserFCMToken(currentUser['uid'], token);
      if( response['status'] ){
        StorageManager.saveUser( response['user'] );
      }else{
        debugPrint( response['message'].toString() );
      }
    }
  }

  /// GET LOGGED-IN USER INFO & INIT SOCKET
  Future<dynamic> getLoggedInUser() async{
    radiusInMeters = await StorageManager.readData('radius');
    final userInfo = await StorageManager.getUser();
    if( userInfo != null && mounted ){
      dynamic isExist = await userManager.getUserByEmail( userInfo['email'] );
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
      setState(() => currentUser = userInfo );
      // Initialize Socket
      SocketSingleton().init( currentUser['uid'] );
      SocketSingleton().listenToEvent('new-message',  (data) => getChatCounter());
      SocketSingleton().listenToEvent('chat-deleted', (data) => getChatCounter());
      SocketSingleton().listenToEvent('chat-created', (data) => getChatCounter());
      SocketSingleton().listenToEvent('blocked', (data) => getChatCounter() );
      // Update User Availability
      String uid = currentUser['uid'];
      if( ss.socket.connected ){
        ss.socket.emit('set-user-status', { "uid" : uid, "status" : true });
      }else{
        userManager.updateUserAvailability( uid, true );
      }
      getChatCounter();
      _getCurrentLocation();
      getFcmTokenAndPermission();
    }
    return;
  }

  /// GET CHAT COUNTER ON ANY UPDATE IN CHAT
  void getChatCounter(){
    chatCounter = 0;
    ss.socket.emitWithAck('get-all-chats', { 'self' : currentUser['uid'] } , ack: ( response ){
      if( response['status'] == true ){
        List chats = response['chats'];
        // Provider.of<ChatManager>(context, listen: false).currentUserId = currentUser['uid'];
        // Provider.of<ChatManager>(context, listen: false).setChats(chats);

        chats.map( ( e ) {
          int counter = 0;
          final List messages = e['messages'];
          for (var i = 0; i < messages.length; i++) {
            final message = messages[i];
            List read = message['readBy'] ?? [];
            if (message['sender'] != currentUser['uid'] && !read.contains( currentUser['uid'] )) {
              counter++;
            }
          }
          e['counter'] = counter;
          chatCounter = ( counter > 0 ) ? chatCounter+1 : chatCounter;
          setState(() {});
          return e;
        }).toList();
        if( chats.isEmpty ){
          setState(() {});
        }
      }
    });
  }

  /// GET USER CURRENT LOCATION
  Future<void> _getCurrentLocation() async {
    try{
      // CHECK IF PERMISSION IS ALLOWED
      locationStatus = await Permission.locationWhenInUse.status;
      // Check if location is enabled
      isLocationServiceEnabled  = await Geolocator.isLocationServiceEnabled();
      // SET APP-STATE TO OPENED
      bool isLocEnabled = await StorageManager.readData('location-enabled');
      isLocationDenied = await StorageManager.readData('location-denied');

      if( mounted ){
        Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( isLocEnabled );
        Provider.of<PermissionManager>(context, listen: false).setLocationPermissionStatus(locationStatus.isGranted);
        Provider.of<PermissionManager>(context, listen: false).setLocationManagerStatus(isLocationServiceEnabled);
      }

      if( isLocationServiceEnabled && locationStatus.isGranted && mounted && isLocEnabled ){
        position = await Geolocator.getCurrentPosition(
            forceAndroidLocationManager: false,
            desiredAccuracy: LocationAccuracy.high
        );
        if ( currentUser != null && position != null && mounted ){
          // Update User Current Location
          final res = await userManager.updateUserLocation( currentUser['uid'], position.latitude, position.longitude );
          if( res['status'] ){
            StorageManager.saveUser( res['user'] );
          }
          // Get current Geo Points
          final currentGeoPoint = geo.point( latitude: position.latitude, longitude: position.longitude);
          // Find nearby people
          isFindingPeople = true;
          final response = await userManager.getNearbyUsers( currentUser['uid'], currentGeoPoint, radiusInMeters/1000 );
          nearbyUsers = [];
          if( response['status'] ){
            final users = response['users'];
            List myBlockedList = currentUser['blockedBy'] ?? [];
            users.forEach( ( user ) {
              final dynamic settings = user['settings'] ?? false;
              /// CHECK BLOCK & ONLINE CONDITION HERE
              List blockedList = user['blockedBy'] ?? [];
              bool isOnline = user['isOnline'] ?? false;
              bool isVisible = ( settings != false ) ? settings['visible'] : true;
              //bool isOnline = true;
              if( isOnline && isVisible && !blockedList.contains( currentUser['uid'] ) && !myBlockedList.contains(user['uid']) ){
                nearbyUsers.add(user);
              }
            });
          }else{
            if( response['code'] == 'TOKEN_MISSING' || response['code'] == 'TOKEN_EXPIRED' ){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text( response['message'] ),
                ),
              );
              StorageManager.deleteUser();
              Navigator.of(context)
                  .pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (
                          context) => const SignIn()),
                      (Route<
                      dynamic> route) => false);
            }
          }
          if( mounted ){
            setState(() { isFindingPeople = false; });
          }
        }

      }else{
        if ( currentUser != null && mounted ){
          await userManager.updateUserLocation( currentUser['uid'], 0.0, 0.0 );
        }
        debugPrint( 'Location service is disabled' );
        setState(() {
          nearbyUsers = [];
        });
      }
    }
    on Exception catch (e) {
      debugPrint(e.toString()); // Only catches an exception of type `Exception`.
    } catch (e) {
      debugPrint(e.toString()); // Catches all types of `Exception` and `Error`.
    }
  }

  @override
  void dispose() {
    debugPrint('Disposing at Home');
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    bool isRTL() => Directionality.of(context).index != 0;

    return Stack(
      children: [
        Positioned.fill(child: DefaultTabController(
          length: 2,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              backgroundColor: myColors.appSecBgColor,
              body: Stack(
                children: [
                  Positioned.fill(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _tabController,
                        children: [
                          WillPopScope(
                              child: Consumer2<PermissionManager, LocationManager>(
                                        builder: (context, permissionManager, locationManager, child) {
                                          return ( locationManager.isLocationDenied || !locationManager.isLocationPermissionGranted || position == null || position?.latitude == 0 || position?.longitude == 0 ) ? const EmptyMap() :
                                          CustomMap(
                                            nearbyUsers: nearbyUsers, lat : position?.latitude ?? 0.0, lng: position?.longitude ?? 0.0, loggedInUser: currentUser,
                                          );
                                        }
                              ),
                              onWillPop: () async { return false;}
                          ),
                          WillPopScope(child: Directionality(
                            textDirection: (isRTL()) ? TextDirection.ltr : TextDirection.rtl,
                            child: ( nearbyUsers.length > 1 ) ? ListView.builder(
                              itemCount: nearbyUsers.length, // assuming you have a list of chat users
                              itemBuilder: (context, index) {
                                dynamic user = nearbyUsers[index];
                                final statusText = user["status"]["text"];
                                final status = '${LanguageNotifier.of(context)!.translate(user["status"]["option"]+'_abbr')} $statusText';
                                final isStatusEmpty = statusText == "" ? true : false;
                                //const isStatusEmpty = false;

                                final coordinates = user['location']['coordinates'];

                                Color background = Colors.black.withOpacity(0.2);
                                const Distance distance = Distance();
                                final double meter = distance(
                                    LatLng(coordinates[1], coordinates[0]),
                                    LatLng(position!.latitude,position!.longitude)
                                );
                                if( ( currentUser['uid'] == user['_id'] ) ){
                                  background = Colors.black.withOpacity(0.2);
                                }else if( (meter/radiusInMeters) < 0.33 ){
                                  background = Colors.green;
                                }
                                else if( (meter/radiusInMeters) < 0.66 ){
                                  background = Colors.yellow;
                                }
                                else if( (meter/radiusInMeters) < 1 ){
                                  background = Colors.red;
                                }else{
                                  background = Colors.red;
                                }
                                if( ( currentUser['uid'] == user['_id'] ) ){
                                  return Column();
                                }

                                final userDistance = '${(meter/1000).toStringAsFixed(2)} ${LanguageNotifier.of(context)!.translate('km')}';
                                final avatarUrl = (user['avatar']['type'] == 'network') ? UserManager().getServerUrl('/').toString()+user['avatar']['url'] : user['avatar']['url'];

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ListTile(
                                      leading: FittedBox(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: <Widget> [

                                            CircleAvatar(
                                              backgroundColor: background,
                                              radius: 20.0,
                                              child: UserAvatar(url: avatarUrl, type: user['avatar']['type'], radius: 18.0),
                                              // child: CircleAvatar(
                                              //   backgroundColor: Colors.white,
                                              //   radius: 18.0,
                                              //   backgroundImage: (user['avatar']['type'] == 'avatar') ?  AssetImage(user['avatar']['url']) : NetworkImage(UserManager().getServerUrl('/').toString()+user['avatar']['url']) as ImageProvider,
                                              //   //child: Text('FN'),
                                              //   //backgroundImage: NetworkImage(chatUsers[index].avatarUrl),
                                              // ),
                                            ),
                                          ],
                                        ),

                                      ),
                                      minLeadingWidth : 20,
                                      //title: Text(chatUsers[index].name),
                                      title : Column(
                                        mainAxisAlignment : MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.fitWidth,
                                            child: Row(
                                              children: [
                                                Text(user['username'], style: const TextStyle(fontSize: 16),),
                                                const SizedBox(width: 10,),
                                                Text(userDistance, style: const TextStyle(fontSize: 14),)
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      //title: Text(user['username']+' '+userDistance),
                                      subtitle : isStatusEmpty ? const Text('', style: TextStyle(fontSize: 0.0),): Text(status),
                                      trailing: IconButton(
                                        icon: SvgPicture.asset(
                                          'assets/message_icon.svg',
                                          width: 22,
                                          colorFilter: ColorFilter.mode(myColors.brandColor!, BlendMode.srcIn),
                                        ),
                                        onPressed: (){
                                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => Chat( currentUser: currentUser, receiverUserId: user['_id'])),).then((value) {
                                            //_getCurrentLocation();
                                          });
                                        },
                                      ),
                                    ),
                                    const Padding (
                                      padding: EdgeInsets.symmetric(horizontal: 15.0),
                                      child: Divider(height: 2, color: Colors.grey),
                                    ),
                                  ],
                                );
                              },
                            ) : Center(child: Text(LanguageNotifier.of(context)!.translate('no_users_nearby')),),
                          ), onWillPop: () async { Navigator.pushReplacementNamed(context, '/home'); return true; } )
                        ],
                      )
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        if (details.delta.dx > 10) {
                          Navigator.pushNamed(context, '/messages').then((value) async {
                            int currentTab = await StorageManager.readData('home-tab') ?? 0;
                            if( _tabController.index != currentTab ){
                              setState(() => _tabController.animateTo(currentTab) );
                            }
                            getChatCounter();
                          });
                        }
                      },
                      child: Container(
                        width: 30,
                        color: Colors.transparent,
                        height: MediaQuery.of(context).size.height,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        if (details.delta.dx < 10) {
                          Navigator.pushNamed(context, '/menu').then((value) async {
                            int currentTab = await StorageManager.readData('home-tab') ?? 0;
                            if( _tabController.index != currentTab ){
                              setState(() => _tabController.animateTo(currentTab) );
                            }
                            getChatCounter();
                          });
                        }
                      },
                      child: Container(
                        width: 20,
                        color: Colors.transparent,
                        height: MediaQuery.of(context).size.height,
                      ),
                    ),
                  ),
                  Positioned(
                    // child: Image.asset( 'assets/nav_icon_bg.png' ),
                    bottom: 50,
                    left: MediaQuery.of(context).size.width*0.5 - 165,
                      child: SvgPicture.asset(
                        'assets/nav_icon_bg.svg',
                        width: 250,
                        height: 70,
                        colorFilter: ColorFilter.mode(myColors.brandColor!, BlendMode.srcIn),
                      ),

                  ),
                  Positioned(
                    // child: Image.asset( 'assets/nav_icon_bg.png' ),
                    bottom: 60,
                    left: MediaQuery.of(context).size.width*0.5 - 25,
                    child: Consumer2<PermissionManager, LocationManager>(
                      builder: (context, permissionManager, locationManager, child) {

                        bool isLocLoading = (locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied) && (position == null || position?.latitude == 0 || position?.longitude == 0);

                        return InkWell(
                          child:
                          ( isLocLoading ) ?
                            Image.asset(
                              'assets/LOADING_1.webp',
                              width: 50,
                            ) :
                          ( locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? SvgPicture.asset(
                            'assets/location_icon.svg',
                            width: 50,
                          ) :
                          SvgPicture.asset(
                            'assets/app_icon.svg',
                            width: 50,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                          onTap: (){
                            // ENABLE PERMISSION [IF PERMISSIONS ARE DISABLED]
                            if( !permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled ){
                              Geolocator.openLocationSettings();
                            }
                            // ENABLE LOCATION [IF IN-APP LOCATION IS DISABLED]
                            else if( !locationManager.isLocationPermissionGranted && locationManager.isLocationDenied ){
                              Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( true );
                              Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( false );
                            }
                            // DISABLE LOCATION [IF IN-APP LOCATION IS ENABLED]
                            else if( locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ){
                              Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
                              Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( true );
                            }
                          },
                        );
                      }
                    )
                  ),
                  Positioned(
                    bottom: 0,
                      child: Container(
                        height: 55,
                        width: MediaQuery.of(context).size.width,
                        // decoration: const BoxDecoration(
                        //   borderRadius: BorderRadius.only(
                        //       topRight: Radius.circular(25),
                        //       topLeft: Radius.circular(25)),
                        //   boxShadow: [
                        //     BoxShadow(color: Colors.black12, spreadRadius: 0, blurRadius: 10),
                        //   ],
                        //   color: Colors.transparent,
                        // ),
                        child:  Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: myColors.brandColor,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                badges.Badge(
                                  badgeStyle: const badges.BadgeStyle(
                                    badgeColor: Colors.red,
                                  ),
                                  showBadge: ( chatCounter > 0 ) ? true : false,
                                  position: badges.BadgePosition.topEnd(top: 5, end: 0),
                                  badgeContent: Text(chatCounter.toString(), style: TextStyle(color: Colors.white),),
                                  child: IconButton(
                                    icon: SvgPicture.asset(
                                      'assets/speech.svg',
                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    ),
                                    onPressed: (){
                                      if( mounted ){
                                        Navigator.pushNamed(context, '/messages').then((value) async {
                                          int currentTab = await StorageManager.readData('home-tab') ?? 0;
                                          if( _tabController.index != currentTab ){
                                            setState(() => _tabController.animateTo(currentTab) );
                                          }
                                          getChatCounter();
                                        });
                                      }

                                    },
                                  ),
                                ),
                                GestureDetector(
                                  onLongPress: (){
                                    if( _tabController.index == 0 ){
                                      setState(() => _tabController.animateTo(1) );
                                      StorageManager.saveData('home-tab', 1);
                                    }else{
                                      setState(() => _tabController.animateTo(0) );
                                      StorageManager.saveData('home-tab', 0);
                                    }
                                  },
                                  onHorizontalDragEnd: (detail) {
                                    if( _tabController.index == 0 ){
                                      setState(() => _tabController.animateTo(1) );
                                      StorageManager.saveData('home-tab', 1);
                                    }else{
                                      setState(() => _tabController.animateTo(0) );
                                      StorageManager.saveData('home-tab', 0);
                                    }
                                  },
                                  child: IconButton(
                                    onPressed: (){
                                      if( _tabController.index == 0 ){
                                        setState(() => _tabController.animateTo(1) );
                                        StorageManager.saveData('home-tab', 1);
                                      }else{
                                        setState(() => _tabController.animateTo(0) );
                                        StorageManager.saveData('home-tab', 0);
                                      }
                                    },
                                    //icon: Icon(Icons.map_outlined, color: Colors.white,),
                                    icon: SvgPicture.asset(
                                      (_tabController.index == 0) ? 'assets/listview.svg' : 'assets/mapview.svg',
                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: (){
                                    Navigator.pushNamed(context, '/menu').then((value) {
                                      getChatCounter();
                                    });
                                  },
                                  //icon: Icon(Icons.person_outline_rounded, color: Colors.white,),
                                  icon: SvgPicture.asset(
                                    'assets/profile.svg',
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                ),
                                // IconButton(
                                //   onPressed: () => Navigator.pushNamed(context, '/messages'),
                                //   icon: SvgPicture.asset(
                                //     'assets/message_icon.svg',
                                //     colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      )
                  )
                ],
              ),
              // bottomNavigationBar: Container(
              //   height: 50,
              //   decoration: BoxDecoration(
              //     borderRadius: const BorderRadius.only(
              //         topRight: Radius.circular(25), topLeft: Radius.circular(25)),
              //     boxShadow: const [
              //       BoxShadow(color: Colors.black12, spreadRadius: 0, blurRadius: 10),
              //     ],
              //     color: myColors.appSecBgColor,
              //   ),
              //   child:  Padding(
              //     padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              //     child: Container(
              //       padding: const EdgeInsets.symmetric(horizontal: 10),
              //       decoration: BoxDecoration(
              //         color: myColors.brandColor,
              //         borderRadius: BorderRadius.circular(100),
              //       ),
              //       child: Row(
              //         mainAxisSize: MainAxisSize.max,
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: <Widget>[
              //           badges.Badge(
              //             badgeStyle: const badges.BadgeStyle(
              //               badgeColor: Colors.red,
              //             ),
              //             showBadge: ( chatCounter > 0 ) ? true : false,
              //             position: badges.BadgePosition.topEnd(top: 5, end: 0),
              //             badgeContent: Text(chatCounter.toString(), style: TextStyle(color: Colors.white),),
              //             child: IconButton(
              //               icon: SvgPicture.asset(
              //                 'assets/speech.svg',
              //                 colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              //               ),
              //               onPressed: (){
              //                 if( mounted ){
              //                   Navigator.pushNamed(context, '/messages').then((value) async {
              //                     int currentTab = await StorageManager.readData('home-tab') ?? 0;
              //                     if( _tabController.index != currentTab ){
              //                       setState(() => _tabController.animateTo(currentTab) );
              //                     }
              //                     getChatCounter();
              //                   });
              //                 }
              //
              //               },
              //             ),
              //           ),
              //           GestureDetector(
              //             onLongPress: (){
              //               if( _tabController.index == 0 ){
              //                 setState(() => _tabController.animateTo(1) );
              //                 StorageManager.saveData('home-tab', 1);
              //               }else{
              //                 setState(() => _tabController.animateTo(0) );
              //                 StorageManager.saveData('home-tab', 0);
              //               }
              //             },
              //             onHorizontalDragEnd: (detail) {
              //               if( _tabController.index == 0 ){
              //                 setState(() => _tabController.animateTo(1) );
              //                 StorageManager.saveData('home-tab', 1);
              //               }else{
              //                 setState(() => _tabController.animateTo(0) );
              //                 StorageManager.saveData('home-tab', 0);
              //               }
              //             },
              //             child: IconButton(
              //               onPressed: (){
              //                 if( _tabController.index == 0 ){
              //                   setState(() => _tabController.animateTo(1) );
              //                   StorageManager.saveData('home-tab', 1);
              //                 }else{
              //                   setState(() => _tabController.animateTo(0) );
              //                   StorageManager.saveData('home-tab', 0);
              //                 }
              //               },
              //               //icon: Icon(Icons.map_outlined, color: Colors.white,),
              //               icon: SvgPicture.asset(
              //                 (_tabController.index == 0) ? 'assets/listview.svg' : 'assets/mapview.svg',
              //                 colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              //               ),
              //             ),
              //           ),
              //           IconButton(
              //             onPressed: (){
              //               Navigator.pushNamed(context, '/menu').then((value) {
              //                 getChatCounter();
              //               });
              //             },
              //             //icon: Icon(Icons.person_outline_rounded, color: Colors.white,),
              //             icon: SvgPicture.asset(
              //               'assets/profile.svg',
              //               colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              //             ),
              //           ),
              //           // IconButton(
              //           //   onPressed: () => Navigator.pushNamed(context, '/messages'),
              //           //   icon: SvgPicture.asset(
              //           //     'assets/message_icon.svg',
              //           //     colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              //           //   ),
              //           // ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
            ),
          ),
        )),
        Positioned(
            child: Consumer2<PermissionManager, LocationManager>(
                builder: (context, permissionManager, locationManager, child) {
                  return ( (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ?
                  UtilityService().showLocationAlertDialog(
                    context,
                    currentUser,
                    _getCurrentLocation,
                    type: 'permission',
                    privacyDisabled: locationManager.isPrivacyDisabled
                  ) :
                  ( !locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? UtilityService().showLocationAlertDialog(
                      context,
                    currentUser,
                      _getCurrentLocation,
                      privacyDisabled: locationManager.isPrivacyDisabled
                  ) : Container();
                }
            )
        )

      ],
    );
  }


  Widget showAlertDialog( String text ){
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
                child: FilledButton(onPressed: (){ Geolocator.openLocationSettings(); }, child: Text( 'Go to settings' ),),
              ),
              const SizedBox(height: 0,),
              TextButton(
                  onPressed: (){
                    setState(() {});
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
}