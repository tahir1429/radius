import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image/image.dart' as img;
import 'dart:io' show File, Platform;
import 'package:image_picker/image_picker.dart';
import '../services/languageManager.dart';
import '../services/themeManager.dart';

class Camera extends StatefulWidget {
  final ValueChanged<XFile> onSelectFile;
  final void Function(XFile, String) onSelect;
  bool showGallery;

  Camera({Key? key, required this.onSelectFile, required this.onSelect, required this.showGallery}) : super(key: key);

  @override
  State<Camera> createState() => _CameraState();
}


class _CameraState extends State<Camera> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = <CameraDescription>[];
  CameraController? controller;
  XFile? imageFile;
  bool enableAudio = true;
  double _cameraZoom = 1.0;
  double _scaleFactor = 1.0;

  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  // Counting pointers (number of user fingers on screen)
  int selectedCamera = 0;
  FlashMode flashMode = FlashMode.off;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getAvailableCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
    }
  }

  /// GET LIST OF ALL AVAILABLE CAMERAS
  Future<void> getAvailableCameras() async {
    try {
      _cameras = await availableCameras();
      if( _cameras.isNotEmpty ){
        // BY DEFAULT SELECT FIRST CAMERA
        selectedCamera = 1;
        _initializeCameraController( _cameras.first, isNew: true );
      }
      if( mounted ){
        setState(() {});
      }
    } on CameraException catch (e) {
      showInSnackBar('${e.code}\n${e.description}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    // TODO: implement dispose
    super.dispose();
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _initializeCameraController( CameraDescription cameraDescription, { bool isNew = false } ) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    controller = cameraController;
    flashMode = FlashMode.off;
    cameraController.addListener(() {
      if (mounted) {
        controller?.setFlashMode( flashMode);
        setState(() {});
      }
      if ( cameraController.value.hasError ) {
        showInSnackBar(
            'Camera error ${cameraController.value.errorDescription}');
      }
    });

    try{
      const kIsWeb = false;
      await cameraController.initialize();
      await Future.wait(<Future<Object?>>[
        // The exposure mode is currently not supported on the web.
        ...!kIsWeb
            ? <Future<Object?>>[
          cameraController.getMinExposureOffset().then(
                  (double value) => _minAvailableExposureOffset = value),
          cameraController
              .getMaxExposureOffset()
              .then((double value) => _maxAvailableExposureOffset = value)
        ]
            : <Future<Object?>>[],
        cameraController
            .getMaxZoomLevel()
            .then((double value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((double value) => _minAvailableZoom = value),
      ]);
    }on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          showInSnackBar('You have denied camera access.');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
        // iOS only
          showInSnackBar('Please go to Settings app to enable camera access.');
          break;
        case 'CameraAccessRestricted':
        // iOS only
          showInSnackBar('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          showInSnackBar('You have denied audio access.');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
        // iOS only
          showInSnackBar('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
        // iOS only
          showInSnackBar('Audio access is restricted.');
          break;
        default:
          showInSnackBar( e.toString() );
          //_showCameraException(e);
          break;
      }
    }

  }

  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
            ),
            const SizedBox(height: 20,),
            ( _cameras.isEmpty ) ? const Text('Camera not found', style: TextStyle(color: Colors.white, fontSize: 16),) : Container()
          ],
        ),
      );
    } else {
      final mediaSize = MediaQuery.of(context).size;
      final scale = 1 / (cameraController.value.aspectRatio * mediaSize.aspectRatio);

      return ClipRect(
        clipper: _MediaSizeClipper(mediaSize),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: CameraPreview(
            controller!,
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onTapDown: (TapDownDetails details) => onViewFinderTap(details, constraints),
                    onDoubleTap: _handleCameraViewToggle,
                  );
                }),
          ),
        ),
      );
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _cameraZoom = _scaleFactor;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (controller == null ) {
      return;
    }
    _scaleFactor = (_cameraZoom * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    await controller!.setZoomLevel(_scaleFactor);
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    try{
      final CameraController cameraController = controller!;

      double fullWidth = MediaQuery.of(context).size.width;
      double cameraHeight = fullWidth * controller!.value.aspectRatio;

      final Offset offset = Offset(
          details.localPosition.dx / fullWidth,
          details.localPosition.dy / cameraHeight
      );
      // final Offset offset = Offset(
      //   details.localPosition.dx / constraints.maxWidth,
      //   details.localPosition.dy / constraints.maxHeight,
      // );
      cameraController.setExposurePoint(offset);
      cameraController.setFocusPoint(offset);
    } on CameraException catch (e) {
      debugPrint( e.toString() );
      debugPrint( e.code );
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      return controller!.setDescription(cameraDescription);
    } else {
      return _initializeCameraController(cameraDescription);
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      final XFile file = await cameraController.takePicture();
      if( Platform.isIOS && _cameras[selectedCamera-1].lensDirection == CameraLensDirection.front ){
        final image = img.decodeImage(await file.readAsBytes());
        final correctedImage = img.copyRotate(image!, angle: -90); // Apply rotation if necessary
        // 1. Flip Image
        final flippedImage = img.flipHorizontal(image!);
        final flippedBytes = img.encodeJpg(flippedImage);
        // 2. Convert to File
        File newImage = File( file.path );
        // 3. write the image back to disk
        await newImage.delete();
        final flippedFile = await newImage.writeAsBytes(flippedBytes);
        // 4. Convert to XFile & return
        return XFile(flippedFile.path);
      }else{
        return file;
      }
    } on CameraException catch (e) {
      showInSnackBar(e.toString());
      return null;
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((XFile? file) {
      if (mounted) {
        if (file != null) {
          widget.onSelect( file, 'camera');
          widget.onSelectFile( file );
          setState(() {
            imageFile = file;
          });
        }else{
          //showInSnackBar('Empty Path');
        }
      }
    });
  }

  /// TOGGLE CAMERA [FRONT, REAR]
  void _handleCameraViewToggle(){
    if( _cameras.length > 1 ){
      if( selectedCamera == _cameras.length ||  selectedCamera == 2 ){
        selectedCamera = 1;
      }else{
        selectedCamera++;
      }
      onNewCameraSelected( _cameras[selectedCamera-1] );
      setState(() {});
    }
  }

  /// CAMERA FLASH LIGHT [OFF , ALWAYS, AUTO]
  void _handleFlashMode(){
    if ( controller == null || !controller!.value.isInitialized ) {
      return;
    }
    // TURN AUTO/ON/OFF CAMERA FLASH
    if( flashMode  == FlashMode.off ){
      controller!.setFlashMode( FlashMode.always );
      flashMode = FlashMode.always;
    }
    else if( flashMode  == FlashMode.always ){
      controller!.setFlashMode( FlashMode.auto );
      flashMode = FlashMode.auto;
    }
    else{
      controller!.setFlashMode( FlashMode.off );
      flashMode = FlashMode.off;
    }
    debugPrint( flashMode.name );
    debugPrint( flashMode.toString() );
    setState(() {});
  }

  Future<void> _selectFromGallery( String type ) async {
    try{
      final picker = ImagePicker();
      if( type == 'photo' ){
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null && mounted) {
          XFile file = XFile(pickedFile.path);
          widget.onSelectFile( file );
          widget.onSelect( file, 'gallery-photo');
        }
      }else{
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null && mounted) {
          XFile file = XFile(pickedFile.path);
          widget.onSelectFile( file );
          widget.onSelect( file, 'gallery-video');
        }
      }
    } on CameraException catch (e) {
      showInSnackBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: _cameraPreviewWidget(),
            ),
            Positioned(
                bottom: 55,
                left: 20,
                child: IconButton(
                    onPressed: _handleFlashMode,
                    icon: Icon(
                      ( flashMode == FlashMode.off ) ? Icons.flash_off_outlined : ( flashMode == FlashMode.always ) ? Icons.flash_on_outlined : Icons.flash_auto_outlined,
                      color: Colors.white,
                      size: 32,
                    )
                )
            ),
            Positioned(
              bottom: 30,
                left: MediaQuery.of(context).size.width * 0.5 - (100/2),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: IconButton(
                      onPressed: (){
                        onTakePictureButtonPressed();
                      },
                      icon: Image.asset(
                        'assets/app_icon.png',
                        width: 60,
                        height: 60,
                        repeat: ImageRepeat.noRepeat,
                        alignment: Alignment.center,
                        color: Colors.white,
                      ),
                  ),
                )
            ),
            Positioned(
                bottom: 55,
                right: (widget.showGallery) ? 70 : 20,
                child: IconButton(
                    onPressed: () => _handleCameraViewToggle(),
                    icon: const Icon(
                      Icons.flip_camera_android,
                      color: Colors.white,
                      size: 32,
                    )
                )
            ),
            ( widget.showGallery ) ? Positioned(
                bottom: 55,
                right: 15,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.photo_outlined, color: Colors.white,),
                  iconSize: 35,
                  position: PopupMenuPosition.over,
                  offset: const Offset(-10, -110),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10.0))
                  ),
                  itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                    PopupMenuItem(
                      value: 'photo',
                      child: Row(children: <Widget>[
                        Icon(
                          Icons.camera_alt_outlined,
                          color: myColors.appSecTextColor!,
                        ),
                        const SizedBox(
                          width: 15.0,
                        ),
                        const Text('Photo'),
                      ]),
                      onTap: () async {},
                    ),
                    // PopupMenuItem(
                    //   value: 'video',
                    //   child: Row(children: <Widget>[
                    //     Icon(
                    //       Icons.videocam_outlined,
                    //       color: myColors.appSecTextColor!,
                    //     ),
                    //     const SizedBox(
                    //       width: 15.0,
                    //     ),
                    //     const Text('Video'),
                    //   ]),
                    //   onTap: () async {},
                    // ),
                  ],
                  onSelected: ( value ){
                    _selectFromGallery( value );
                  },
                ),
            ) : Container(),
          ],
        ),
      ),
    );
  }
}


class _MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const _MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }
  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}