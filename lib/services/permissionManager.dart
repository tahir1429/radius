import 'package:flutter/cupertino.dart';

class PermissionManager with ChangeNotifier {
    // LOCATION PERMISSION GRANTED STATUS BY DEVICE
    bool _isLocationPermissionGranted = true;
    // LOCATION PERMISSION ENABLED STATUS BY DEVICE
    bool _isLocationServiceEnabled = true;

    /// CONSTRUCTOR
    PermissionManager(){
        _isLocationPermissionGranted = true;
        _isLocationServiceEnabled = true;
        notifyListeners();
        // StorageManager.readData('isLocationServiceEnabled').then((value){
        //     _isLocationServiceEnabled = value;
        //     notifyListeners();
        // });
        // StorageManager.readData('isLocationPermissionGranted').then((value){
        //     _isLocationPermissionGranted = value;
        //     notifyListeners();
        // });
    }

    /// SET LOCATION PERMISSION STATUS
    void setLocationPermissionStatus( bool value ) {
        //StorageManager.saveData('isLocationPermissionGranted', value);
        // Set Value
        _isLocationPermissionGranted = value;
        // Notify to all subscribed pages
        notifyListeners();
    }

    /// SET LOCATION ENABLED STATUS
    void setLocationManagerStatus( bool value ) {
        //StorageManager.saveData('isLocationServiceEnabled', value);
        // Set Value
        _isLocationServiceEnabled = value;
        // Notify to all subscribed pages
        notifyListeners();
    }

    /// GET LOCATION PERMISSION STATUS
    get isLocationPermissionGranted => _isLocationPermissionGranted;
    /// GET LOCATION ENABLED STATUS
    get isLocationServiceEnabled => _isLocationServiceEnabled;
}