import 'package:flutter/cupertino.dart';
import 'package:radius_app/services/storageManager.dart';

class LocationManager with ChangeNotifier {
  // Is have location access
  bool _isLocationPermissionGranted = true;
  // is user denied sharing location
  bool _isLocationDenied = false;
  // is privacy pop-up is disabled
  bool _isPrivacyDisabled = false;

  /// Constructor
  LocationManager(){
    // Read Permissions from app storages & notify to subscribed pages
    StorageManager.readData('location-enabled').then((value){
      _isLocationPermissionGranted = (value != null) ? value : true;
        notifyListeners();
    });
    StorageManager.readData('location-denied').then((value){
      _isLocationDenied = (value != null) ? value : true;
      notifyListeners();
    });
    StorageManager.readData('privacy-disabled').then((value){
      _isPrivacyDisabled = (value != null) ? value : false;
      notifyListeners();
    });
  }

  /// SET LOCATION PERMISSION STATUS
  void setLocationPermissionStatus( bool value ) {
    // Save statue to app storage
    StorageManager.saveData('location-enabled', value);
    // Set Permission Status
    _isLocationPermissionGranted = value;
    // Notify to subscribed pages
    notifyListeners();
  }

  /// SET LOCATION DENIED STATUS
  void denyPermissionStatus( bool value ) {
    // Save statue to app storage
    StorageManager.saveData('location-denied', value);
    // Set Deny Status
    _isLocationDenied = value;
    // Notify to subscribed pages
    notifyListeners();
  }

  /// SET PRIVACY POPUP STATUS
  void setPrivacyStatus( bool value ) {
    // Save statue to app storage
    StorageManager.saveData('privacy-disabled', value);
    // Set Popup disabled Status
    _isPrivacyDisabled = value;
    // Notify to subscribed pages
    notifyListeners();
  }
  /// GET LOCATION PERMISSION GRANTED STATUS
  get isLocationPermissionGranted => _isLocationPermissionGranted;
  /// GET LOCATION PERMISSION DENIED STATUS
  get isLocationDenied => _isLocationDenied;
  /// GET PRIVACY POPUP DISABLED STATUS
  get isPrivacyDisabled => _isPrivacyDisabled;
}