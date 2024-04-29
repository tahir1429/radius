import 'package:flutter/cupertino.dart';

class LoaderNotifier with ChangeNotifier {
  // Spinner Status
  bool _isLoading = false;

  /// Constructor
  LoaderNotifier(){
    // Set Default to false (Not loading)
    _isLoading = false;
    // Notify to subscribed pages
    notifyListeners();
  }

  /// SET LOADER STATUS
  void setLoader( bool value ) {
    // Set loader value
    _isLoading = value;
    // Notify to subscribed pages
    notifyListeners();
  }

  /// GET LOADER STATUS
  get isLoading => _isLoading;
}