import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:custom_map_markers/custom_map_markers.dart';

String? _darkMapStyle;
String? _lightMapStyle;

class EmptyMap extends StatefulWidget {
  const EmptyMap({Key? key}) : super(key: key);

  @override
  State<EmptyMap> createState() => _EmptyMapState();
}

class _EmptyMapState extends State<EmptyMap> {
  late GoogleMapController googleMapController;
  LatLng? myCurrentPosition = const LatLng(23.8859, 45.0792);
  Set<Marker> markers = Set();
  final List<MarkerData> _customMarkers = [];
  double radiusInMeters = 100.0;
  double zoomLevel = 18.0;
  bool isMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

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

            return GoogleMap(
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
