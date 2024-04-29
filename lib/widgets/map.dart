import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/pages/chat.dart';
import 'package:custom_map_markers/custom_map_markers.dart';
import 'package:radius_app/widgets/userAvatar.dart';

final geo = GeoFlutterFire();
String? _darkMapStyle;
String? _lightMapStyle;

class CustomMap extends StatefulWidget {
  final List<Object?> nearbyUsers;
  final dynamic lat;
  final dynamic lng;
  final dynamic loggedInUser;
  const CustomMap({Key? key, required this.nearbyUsers, required this.lat, required this.lng, required this.loggedInUser}) : super(key: key);

  @override
  State<CustomMap> createState() => _CustomMapState();
}

class _CustomMapState extends State<CustomMap> {
  UserManager userManager = UserManager();
  UtilityService utilityService = UtilityService();
  CollectionReference collectionReference = FirebaseFirestore.instance.collection('users');
  dynamic currentUser;
  Timer? timer;
  Position? _position;
  double zoomLevel = 18.0;
  double radiusInMeters = 100.0; // Radius of the circle in meters
  List<Object?> users = [];
  bool showSpinner = true;
  bool isFindingPeople = false;
  bool activityLoaded = true;
  dynamic subscription;
  String selectedLang = '';

  late GoogleMapController googleMapController;
  LatLng? myCurrentPosition;
  Set<Marker> markers = Set();
  List<MarkerData> _customMarkers = [];
  bool isMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSettings();
    users = widget.nearbyUsers;
    currentUser = widget.loggedInUser;
    myCurrentPosition = LatLng(widget.lat, widget.lng);
    timer = Timer.periodic(const Duration(seconds: 5), (Timer t) => _getCurrentLocation());
  }

  Future _loadSettings() async {
    _darkMapStyle  = await rootBundle.loadString('assets/map_dark.json');
    _lightMapStyle = await rootBundle.loadString('assets/map_light.json');
    final double radius = await StorageManager.readData('radius');
    radiusInMeters = radius;

    if(radiusInMeters<=0) {
      radiusInMeters = 100.0;
    }
    //zoomLevel = 16.0 - log(radiusInMeters / 500) / ln2;
    setState(() {});
  }

  @override
  void didUpdateWidget(CustomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    users = widget.nearbyUsers;
    currentUser = widget.loggedInUser;
    myCurrentPosition = LatLng(widget.lat, widget.lng);
    addMarkers();
  }

  Future<void> _getCurrentLocation() async {
    try{
      bool isLocationServiceEnabled  = await Geolocator.isLocationServiceEnabled();
      if( isLocationServiceEnabled ){
        final position = await Geolocator.getCurrentPosition(
          forceAndroidLocationManager: true,
          desiredAccuracy: LocationAccuracy.high
        );
        _position = position;
        myCurrentPosition = LatLng(_position!.latitude, _position!.longitude);
        if (mounted) {
          // setState(() {
          //   if( _position != null ){
          //
          //     // _currentLatLng = LatLng(_position!.latitude, _position!.longitude);
          //     // mapController.move(_currentLatLng, zoomLevel);
          //   }
          // });
        }
      }else{
        debugPrint( 'Location service is disabled' );
      }
    }
    on Exception catch (e) {
      debugPrint(e.toString()); // Only catches an exception of type `Exception`.
    } catch (e) {
      debugPrint(e.toString()); // Catches all types of `Exception` and `Error`.
    }
  }

  void _zoomIn() async {
    var currentZoomLevel = await googleMapController.getZoomLevel();
    currentZoomLevel = currentZoomLevel + 1;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: myCurrentPosition!,
          zoom: currentZoomLevel,
        ),
      ),
    );
  }
  void _zoomOut() async {
    var currentZoomLevel = await googleMapController.getZoomLevel();
    currentZoomLevel = currentZoomLevel - 1;
    if (currentZoomLevel < 0) currentZoomLevel = 0;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: myCurrentPosition!,
          zoom: currentZoomLevel,
        ),
      ),
    );
  }
  void recenterMe() async {
      try{
        googleMapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: myCurrentPosition!,
              zoom: zoomLevel,
            ),

          ),
        );
      }catch( e ){
        debugPrint( e.toString() );
      }
  }

  void _onMapCreated(GoogleMapController controller, ThemeNotifier theme ) {
    googleMapController = controller;
    isMapInitialized = true;
    recenterMe();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 100), () {
      if( theme.isLightMode ){
        controller.setMapStyle(_lightMapStyle);
      }else{
        controller.setMapStyle(_darkMapStyle);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    if( subscription != null ){
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  void deactivate() {
    timer?.cancel();
    if( subscription != null ){
      subscription.cancel();
    }
    // TODO: implement deactivate
    super.deactivate();
  }

  dynamic openDialog( BuildContext context, dynamic user ){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    final avatarType = user['avatar']['type'];
    final avatar = (avatarType == 'network') ? UserManager().getServerUrl('/').toString()+user['avatar']['url'] : user['avatar']['url'];
    final username = user['username'];
    final statusText = user["status"]["text"];
    final status = '${LanguageNotifier.of(context)!.translate(user['status']['option']+'_abbr')} $statusText';
    final isStatusEmpty = statusText == "" ? true : false;

    // Calculate Distance (In Meters)
    final coordinates = user['location']['coordinates'];
    double selfLat = _position?.latitude ?? 0;
    double selfLng = _position?.longitude ?? 0;
    final double meter = utilityService.calculateDistanceInMeters(coordinates[1], coordinates[0], selfLat, selfLng);

    Color background = Colors.black.withOpacity(0.2);
    if( ( currentUser['uid'] == user['_id'] ) ){
      background = Colors.black.withOpacity(0.2);
    }else if( (meter/100) < 0.33 ){
      background = Colors.green;
    }
    else if( (meter/100) < 0.66 ){
      background = Colors.yellow;
    }
    else if( (meter/100) < 1 ){
      background = Colors.red;
    }else{
      background = Colors.red;
    }

    showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width: MediaQuery.of(context).size.width*0.9,
          child: SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: background,
                  radius: 40.0,
                  child: UserAvatar(url: avatar, type: avatarType, radius: 37.0),
                ),
                const SizedBox(width: 20.0,),
                Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: const TextStyle(fontSize: 18.0),),
                        isStatusEmpty ? const SizedBox(height: 1.0,): const SizedBox(height: 5.0,),
                        isStatusEmpty ? const Text('', style: TextStyle(fontSize: 8.0)): Text(status, style: const TextStyle(fontSize: 14.0),),
                        isStatusEmpty ? const SizedBox(height: 1.0,): const SizedBox(height: 2.0,),
                        ( currentUser['uid'] != user['_id'] ) ? Text('${(meter/1000).toStringAsFixed(2)} ${LanguageNotifier.of(context)!.translate('km')}', style: const TextStyle(fontSize: 14.0),) : Container(),
                      ],
                    )
                )
              ],
            ),
          ),
        ),
        actions: <Widget>[
          ( currentUser['uid'] == user['_id'] )  ? Container() :
          IconButton(
            onPressed: (){
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => Chat( currentUser: currentUser, receiverUserId: user['_id'])),);
            },
            icon: SvgPicture.asset(
              'assets/message_icon.svg',
              width: 30,
              colorFilter: ColorFilter.mode(myColors.brandColor!, BlendMode.srcIn),
            ),
          ),
        ],
      );
    });
  }

  _customMarker(String type, Color color, String avatar ) {
    return Stack(
      children: [
        Icon(
          Icons.add_location,
          color: color,
          size: 70,
        ),
        Positioned(
          left: 17.5,
          top: 8,
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(100)),
            child: UserAvatar(url: avatar, type: type, radius: 70),
            // child: CircleAvatar(
            //   radius: 70,
            //   backgroundColor: Colors.white.withOpacity(1),
            //   backgroundImage: ( type == 'avatar' ) ? AssetImage(avatar) : NetworkImage(avatar) as ImageProvider,
            // ),
          ),
        )
      ],
    );
  }

  Future<dynamic> addMarkers() async {
    //_customMarkers = [];
    List<MarkerData> temp = [];
    users.map( ( dynamic user ) async {
      final coordinates = user['location']['coordinates'];
      LatLng userPosition = LatLng( coordinates[1], coordinates[0] );
      double selfLat = _position?.latitude ?? 0;
      double selfLng = _position?.longitude ?? 0;
      final double meter = utilityService.calculateDistanceInMeters(coordinates[1], coordinates[0], selfLat, selfLng);

      Color background = Colors.black.withOpacity(0.2);
      if( ( currentUser['uid'] == user['_id'] ) ){
        background = Colors.black.withOpacity(0.2);
      }else if( (meter/radiusInMeters) < 0.33 ){
        background = Colors.green;
      }
      else if( (meter/radiusInMeters) >=0.33 && (meter/radiusInMeters) < 0.66 ){
        background = Colors.yellow;
      }
      else if( (meter/radiusInMeters) >=0.66 && (meter/radiusInMeters) < 1 ){
        background = Colors.red;
      }else{
        background = Colors.red;
      }

      final avatarType = user['avatar']['type'];
      final avatar = (avatarType == 'network') ? UserManager().getServerUrl('/').toString()+user['avatar']['url'] : user['avatar']['url'];


      final marker = MarkerData(
          marker: Marker(
              markerId: MarkerId( user['_id'] ),
              position: userPosition,
              onTap: (){
                openDialog( context, user );
              }
          ),
          child: _customMarker(avatarType, background, avatar ),
      );
      temp.add( marker );
    }).toSet();
    _customMarkers = temp;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    if( subscription != null && !isFindingPeople ){
      subscription?.cancel();
    }

    Set<Circle> circles = {
      Circle(
      circleId: const CircleId('currentCircle'),
        center: myCurrentPosition!,
        radius: radiusInMeters,
        fillColor: myColors.brandColor!.withOpacity(0.2),
        strokeColor:  myColors.brandColor!.withOpacity(0.6),
        strokeWidth: 3,

    )};

    final isEnglish = ( LanguageNotifier.of(context)!.translate('lang') == 'en' ) ? true : false;



    return Consumer<ThemeNotifier>(
      builder: (context, theme, _) => Scaffold(
        backgroundColor: myColors.appSecBgColor,
        body: CustomGoogleMapMarkerBuilder(
          customMarkers: _customMarkers,
          builder : (BuildContext context, Set<Marker>? markers) {
            if( theme.isLightMode && isMapInitialized ){
              googleMapController.setMapStyle(_lightMapStyle);
            }else if( isMapInitialized ){
              googleMapController.setMapStyle(_darkMapStyle);
            }

            return
              ( myCurrentPosition != null && myCurrentPosition?.latitude != 0 && myCurrentPosition?.longitude != 0 )
                  ?
              GoogleMap(
                // gestureRecognizers: Set()
                //   ..add(Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())),
              mapType: MapType.normal,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: false, // true
              myLocationButtonEnabled: false, // true
              tiltGesturesEnabled: false,
              onMapCreated: (GoogleMapController controller){
                _onMapCreated( controller, theme );
              },
              initialCameraPosition: CameraPosition(
                target: myCurrentPosition!,
                zoom: zoomLevel,
              ),
              circles: circles,
              //markers : markers.values.toSet(),
              markers: ( markers == null ) ? {} : markers,
            )
                  :
                    Container(
                      width: MediaQuery.of(context).size.width,
                      child: Center(
                          child: Image.asset(
                              ( isEnglish )
                                  ? (theme.isLightMode) ? 'assets/spinners/light_en.gif' : 'assets/spinners/dark_en.gif'
                                  : (theme.isLightMode) ? 'assets/spinners/light_ar.gif' : 'assets/spinners/dark_ar.gif',
                              colorBlendMode: BlendMode.modulate
                          )
                      ),
                    );
          },
        ),
        floatingActionButton: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          margin: const EdgeInsets.only(bottom: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: "get_loc_btn",
                onPressed: () => recenterMe(),
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: "zoom_in_btn",
                onPressed: _zoomIn,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: "zoom_out_btn",
                onPressed: _zoomOut,
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      ),
    );
  }
}



