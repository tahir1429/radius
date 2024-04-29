import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/pages/avatars.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:badges/badges.dart' as badges;
import 'package:radius_app/widgets/camera.dart';
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:path/path.dart' as path;
import 'package:radius_app/widgets/previewStories.dart';
import 'package:video_player/video_player.dart';
import 'package:custom_image_crop/custom_image_crop.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/widgets/userAvatar.dart';
import 'dart:async';
import 'package:radius_app/services/locationManager.dart';

class Menu extends StatefulWidget {
  final ThemeNotifier theme;
  final VoidCallback onSetLocale;

  const Menu({super.key, required this.theme, required this.onSetLocale});

  @override
  State<Menu> createState() => _MenuState();
}


class _MenuState extends State<Menu> with WidgetsBindingObserver, SingleTickerProviderStateMixin  {
  UserManager userManager = UserManager();
  File? _image;
  File? _profileImage;
  final picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _storyCaptionController = TextEditingController();
  LanguageNotifier languageNotifier = LanguageNotifier();
  VideoPlayerController? _videoController;
  String selectedLang = 'en';
  dynamic selectedStatus = 'status_one';
  dynamic selectedStatusText = '';
  dynamic currentUser;
  bool isSavingStatus = false;
  bool isSavingAvatar = false;
  bool isSavingStory  = false;
  dynamic selectedImage = {
    "type": "avatar",
    "url": 'assets/avatars/avatar_1.png'
  };
  bool ifImageTypeNetwork = false;
  bool isHoldingStoryDialog = false;

  int chatCounter = 0;
  final SocketSingleton ss = SocketSingleton();
  int homeTab = 0;
  List<dynamic> myStories = [];
  CustomImageCropController controller = CustomImageCropController();
  String selectedMediaType = '';



  var counterAnimator = 0;
  List<Color> get getColorsList => [
    const Color(0xFF9F8FEF),
    Colors.purple,
  ]..shuffle();

  List<Alignment> get getAlignments => [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomRight,
    Alignment.bottomLeft,
  ];

  _startBgColorAnimationTimer() {
    ///Animating for the first time.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      counterAnimator++;
      setState(() {});
    });

    const interval = Duration(milliseconds: 800);
    Timer.periodic(
      interval,
          (Timer timer) {
            counterAnimator++;
        setState(() {});
      },
    );
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    getSelectedLangCode();
    getUser();
    _startBgColorAnimationTimer();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        getChatCounter();
        debugPrint("app in resumed");
        break;
      case AppLifecycleState.inactive:
        debugPrint("app in inactive");
        break;
      case AppLifecycleState.paused:
        debugPrint("app in paused");
        break;
      case AppLifecycleState.detached:
        debugPrint("app in detached");
        break;
    }
  }

  Future<void> getSelectedLangCode() async {
    final String lang = await languageNotifier.getLocale();
    setState(() {
      selectedLang = lang;
    });
  }

  Future<void> getUser() async {
    final response = await StorageManager.getUser();
    homeTab = await StorageManager.readData('home-tab') ?? 0;

    if (response != null && response['username'] != null && mounted) {
      currentUser = response;
      if( ss.socket.connected ){
        SocketSingleton().listenToCounterEvent((data) => getChatCounter());
      }
      getChatCounter();
      selectedImage['type'] = currentUser['avatar_type'];
      selectedImage['url'] = currentUser['avatar_url'];
      if (currentUser['avatar_type'] == 'network') {
        ifImageTypeNetwork = true;
      }
      selectedStatus = currentUser['status_option'];
      selectedStatusText = currentUser['status_text'];
      getUserStories( currentUser['uid'] );
      setState(() {});
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignIn()),
          (Route<dynamic> route) => false);
    }
    setState(() => {});
  }

  Future<void> getUserStories( dynamic uid ) async {
    try{
      final response = await userManager.getMyStories( uid );
      if( response['status'] && mounted){
        setState(() {
          myStories = response['stories'];
        });
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text( response['message'] ),
          ),
        );
      }
    }catch( e ){
      if( mounted ){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text( e.toString() ),
          ),
        );
      }
    }
  }

  void getChatCounter(){
    chatCounter = 0;
    ss.socket.emitWithAck('get-all-chats', { 'self' : currentUser['uid'] } , ack: ( response ){
      if( response['status'] == true ){
        List chats = response['chats'];
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
          if( mounted ) setState(() {});
          return e;
        }).toList();
        if( chats.isEmpty && mounted ){
          setState(() {});
        }
      }
    });
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.getImage(source: source);
    if (pickedFile != null && mounted) {
      setState(() { isSavingAvatar = true; });
      _image = File(pickedFile.path);
      if( mounted ){
        //_cropImage( _image! );
        _previewSelectedProfileImage();
        //updateAvatarInformation( _image!.path, 'network' );
      }
    } else {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('No image selected.'),
      //   ),
      // );
    }
    setState(() { isSavingAvatar = false; });
  }

  void cropImage() async {
    setState(() { isSavingAvatar = true; _profileImage = _image; });
    final MemoryImage? image = await controller.onCropImage();
    _image = await ImageConverter.convertMemoryImageToFile(image!);
    setState(() {
      _profileImage = _image;
    });
    updateAvatarInformation( _image!.path, 'network');
  }

  void _previewSelectedProfileImage(){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    showGeneralDialog(
        context: context,
        barrierColor: Colors.transparent,
        pageBuilder: (_, animation1, ___) {
          return StatefulBuilder(
              builder: (context, setState ) {
                dynamic screenWidth = MediaQuery.of(context).size.width;
                return Scaffold(
                  backgroundColor: Colors.black,
                  body: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                          child : _cropImage( _image! )
                      ),
                      Positioned(
                        bottom: 40,
                        left: 40,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(LanguageNotifier.of(context)!.translate('cancel'), style: const TextStyle(color: Colors.white, fontSize: 18),),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        right: 40,
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(context).pop();
                            cropImage();
                          },
                          child: Text(LanguageNotifier.of(context)!.translate('done'), style: const TextStyle(color: Colors.white, fontSize: 18),),
                        ),
                      ),
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  Future<void> _uploadImage( dynamic image ) async {
    try{
      setState(() { isSavingAvatar = true; });
      if ( mounted ) {
        // code to update the user's profile with the image URL
        _previewSelectedProfileImage();
      }
    }catch( e ){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text( e.toString() ),
        ),
      );
    }
    setState(() { isSavingAvatar = false; });
  }

  Future<void> _showPreviewDialog(BuildContext context) async {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    TextEditingController statusController = TextEditingController(text: selectedStatusText);
    bool isLoading = false;

    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(LanguageNotifier.of(context)!.translate('status')),
            content: StatefulBuilder(
                builder: (context, setState) {
                  return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton(
                      style: TextStyle(
                          fontSize: 16.0,
                          height: 1.0,
                          color: myColors.appSecTextColor),
                      isExpanded: false,
                      isDense: true,
                      underline: Container(),
                      borderRadius: const BorderRadius.all(Radius.circular(15)),
                      value: selectedStatus,
                      items: <String>['status_one', 'status_two']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                              LanguageNotifier.of(context)!.translate('${value}_abbr')),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                    TextFormField(
                      controller: statusController,
                      style: const TextStyle(fontSize: 16.0, height: 1.0),
                      decoration: InputDecoration(
                        labelText:
                            LanguageNotifier.of(context)!.translate('status'),
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
                        prefix: Text(
                          '${LanguageNotifier.of(context)!.translate(selectedStatus+'_abbr')} ',
                          style: TextStyle(color: myColors.appSecTextColor),
                        ),
                      ),
                      onChanged: (value) {},
                    ),
                  ],
                ),
              );
                }
            ),
            actions: <Widget>[
              (isLoading == true ) ?
              FilledButton(
                      onPressed: (){},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox( width: 20, height: 20, child: CircularProgressIndicator( color: Colors.white, strokeWidth: 2,),),
                          const SizedBox(width: 10,),
                          Text(LanguageNotifier.of(context)!.translate('update'))
                        ],
                      )
                  )
              :
              FilledButton(
                child: Text(LanguageNotifier.of(context)!.translate('update') ),
                onPressed: () async {
                  setState(() { isLoading = true; });
                  final response = await userManager.updateUserBio(
                      currentUser['uid'],
                      selectedStatus,
                      statusController.text
                  );
                  if (response['status'] && context.mounted) {
                    currentUser['status_option'] = selectedStatus;
                    currentUser['status_text'] = statusController.text;
                    StorageManager.saveUser( response['user'] );
                    selectedStatusText = statusController.text;
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['message']),
                      ),
                    );
                  }
                  setState(() {
                    isLoading = false;
                  });
                },
              ),
            ],
          );
        });
  }

  Widget _cropImage( File image ) {
    final paint = Paint();
    paint.color = Colors.blue;

    return AspectRatio(
      aspectRatio: 1,
      child: CustomImageCrop(
        drawPath: SolidCropPathPainter.drawPath,
        backgroundColor: Colors.black,
        cropController: controller,
        image: FileImage(image), // Any Imageprovider will work, try with a NetworkImage for example...
        shape: CustomCropShape.Circle,
        cropPercentage: 0.7,
      ),
    );
  }

  void showCameraDialog( BuildContext context, Future<void> Function( dynamic image ) callback, { bool showGallery = false }  ){
    showGeneralDialog(
        context: context,
        barrierColor: Colors.black12.withOpacity(1),
        pageBuilder: (_, __, ___) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
                builder: (context, setState ) {
                  return Consumer2<PermissionManager, LocationManager>(
                      builder: (context, permissionManager, locationManager, child) {
                        return Dismissible(
                          direction: DismissDirection.vertical,
                          onDismissed: (_) {
                            Navigator.of(context).pop();
                          },
                          key: const Key("key"),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Camera(
                                  onSelectFile : ( XFile file ){},
                                  onSelect: ( XFile file, String type ){
                                    File image = File(file.path);
                                    _image = image;
                                    selectedMediaType = type;
                                    print(selectedMediaType);
                                    Navigator.pop(context);
                                    callback( _image );
                                  },
                                  showGallery: showGallery,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: AppBar(
                                  backgroundColor: Colors.transparent,
                                  leading: IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close)
                                  ),
                                  centerTitle: true,
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.transparent,
                                        radius: 20.0,
                                        child: UserAvatar(url: currentUser['avatar_url'], type: currentUser['avatar_type'], radius: 17.0),
                                      ),
                                      const SizedBox(width: 10.0,),
                                      Expanded(
                                          child: Text(
                                              currentUser['username'],
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white)
                                          )
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ( (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? Positioned(
                                  child: UtilityService().showLocationAlertDialog(
                                      context,
                                      currentUser,
                                      refreshState,
                                      type: 'permission'
                                  )
                              ) :
                              ( !locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? Positioned(
                                  child: UtilityService().showLocationAlertDialog(
                                      context,
                                      currentUser,
                                      refreshState,
                                  )
                              ) :
                              Container(),
                            ],
                          ),
                        );
                      }
                  );
                }
            ),
          );
        }
    );
  }

  void updateAvatarInformation(dynamic file, String type) async {
    setState(() { isSavingAvatar = true; });
    //selectedImage = {"type": type, "url": file};
    final response = await userManager.updateUserAvatar(
        currentUser['uid'],
        { 'type' : type, 'url' : file },
        _image
    );
    if (response['status'] && mounted) {
      StorageManager.saveUser( response['user'] );
      currentUser = await StorageManager.getUser();
      selectedImage['type'] = currentUser['avatar_type'];
      selectedImage['url'] = currentUser['avatar_url'];

      if( mounted ){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageNotifier.of(context)!.translate('uploaded_success')),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text( response['message'] ),
        ),
      );
    }
    setState(() { isSavingAvatar = false; });
  }

  void goToAvatarPage() async {
    final information = await Navigator.push(
      context,
      CupertinoPageRoute(
          fullscreenDialog: true, builder: (context) => const Avatars()),
    );
    if (information != null) {
      updateAvatarInformation(information, "avatar");
    }
  }

  void logout() async {
    await userManager.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const SignIn()),
              (Route<dynamic> route) => false);
    }
  }

  Future<void> _previewNewStoryDialog( dynamic image ) async {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    List<String> videoExtensions = ['.mov', '.mp4', '.webm', '.ogg', '.avi', '.flv', '.mpg', '.mpeg'];
    List<String> imageExtensions = ['.jpg', '.jpeg', '.gif', '.png', '.raw', '.bmp', '.tif', '.tiff'];
    bool isVideo = false;
    FocusNode focusNode = FocusNode();

    if( image != null ){
      String ext = path.extension( ( image as File ).path );

      if( videoExtensions.contains( ext.toLowerCase() ) ){
        isVideo = true;
      }
    }

    _storyCaptionController.clear();
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black12.withOpacity(1),
      pageBuilder: (_, animation1, ___) {
        return StatefulBuilder(
            builder: (context, setState ) {
              if( isVideo && _videoController == null ){
                _videoController = VideoPlayerController.file(
                    image,
                    videoPlayerOptions: VideoPlayerOptions(

                    )
                )
                  ..initialize().then((_) {
                    // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
                    setState(() {});
                  })
                  ..addListener(() {
                    print('Listener');
                    setState(() {});
                  });
              }

              return Scaffold(
                backgroundColor: Colors.black12.withOpacity(1),
                body: Directionality(
                    textDirection: TextDirection.ltr,
                    child: GestureDetector(
                      onTap: () => focusNode.unfocus(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ( image != null ) ? Positioned.fill(
                            child: ( !isVideo ) ?
                            (selectedMediaType == 'camera') ?
                            Image.file(image, fit: BoxFit.fitHeight, height: double.infinity, width: double.infinity, alignment: Alignment.center ) :
                            Image.file(image, fit: BoxFit.contain) :
                            ( _videoController != null && _videoController!.value.isInitialized ) ?
                            AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!)
                            ) :
                            Center( child: CircularProgressIndicator(color: myColors.brandColor!),),
                          ) : Container(),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AppBar(
                              backgroundColor: Colors.transparent,
                              leading: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close)
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 100,
                                  padding: const EdgeInsets.all(5),
                                  child: TextFormField(
                                    focusNode: focusNode,
                                    style: const TextStyle(
                                        color: Colors.white
                                    ),
                                    cursorColor: Colors.white,
                                    controller: _storyCaptionController,
                                    keyboardType: TextInputType.multiline,
                                    minLines: 1,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.black.withOpacity(0.5),
                                        hintText: LanguageNotifier.of(context)!.translate('caption'),
                                        hintStyle: const TextStyle(color: Colors.white),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                                        border: OutlineInputBorder(
                                            borderSide: const BorderSide( style: BorderStyle.solid, color: Color(0xFFFFFFFF), width: 0.3   ),
                                            borderRadius: BorderRadius.circular(10)
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide( style: BorderStyle.solid, color: Color(0xFFFFFFFF), width: 0.3 ),
                                            borderRadius: BorderRadius.circular(10)
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                            borderSide: const BorderSide( style: BorderStyle.solid, color: Color(0xFFFFFFFF), width: 0.3 ),
                                            borderRadius: BorderRadius.circular(10)
                                        ),
                                        suffixIcon : IconButton(
                                            icon: const Icon(Icons.send, color: Color(0xFFFFFFFF),),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _uploadStory( image, _storyCaptionController.text );
                                            }
                                        )
                                      // suffixIcon : ( !isSendingMessage ) ?
                                      // IconButton(
                                      //     icon: const Icon(Icons.send, color: Color(0xFFFFFFFF),),
                                      //     onPressed: () async {
                                      //       try{
                                      //         uploadAttachment();
                                      //         Navigator.pop(context);
                                      //       }catch( e ){
                                      //         setState(() { isSendingMessage = false; });
                                      //         debugPrint( e.toString() );
                                      //       }
                                      //     }
                                      // ) :
                                      // SizedBox(
                                      //   width: 25,
                                      //   height: 25,
                                      //   child: Transform.scale(
                                      //     scale: 0.5,
                                      //     child: const CircularProgressIndicator(),
                                      //   ),
                                      // )
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          (isVideo && _videoController != null &&  _videoController!.value.isInitialized) ? Positioned(
                            top: MediaQuery.of(context).size.height * 0.4,
                            left: 0,
                            right: 0,
                            child: IconButton(
                                onPressed: (){
                                  if( _videoController!.value.isPlaying ){
                                    _videoController!.pause();
                                  }else{
                                    _videoController!.play();
                                  }
                                  setState( () => {} );
                                },
                                icon: Icon( (_videoController!.value.isPlaying) ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 60, color: Colors.white.withOpacity(0.6),)
                            ),
                          ) : Container(),
                          (isVideo && _videoController != null &&  _videoController!.value.isInitialized) ? Positioned(
                            top: MediaQuery.of(context).size.height * 1.5,
                            left: 0,
                            right: 0,
                            child: VideoProgressIndicator( _videoController!, allowScrubbing: true,),
                          ) : Container(),
                          // (isVideo && _videoController != null &&  _videoController!.value.isInitialized) ? Positioned(
                          //   top: MediaQuery.of(context).size.height * 3,
                          //   left: 0,
                          //   right: 0,
                          //   child: _ControlsOverlay(controller: _videoController!),
                          // ) : Container()
                        ],
                      ),
                    )
                ),
              );
            }
        );
      },
    );
  }

  void _viewMyStoriesDialog(){
    setState(() => isHoldingStoryDialog = false );
    showGeneralDialog(
        context: context,
        barrierColor: Colors.transparent,
        pageBuilder: (_, animation1, ___) {
          return StatefulBuilder(
            builder: (context, setState ) {
              return Dismissible(
                  direction: DismissDirection.vertical,
                  onDismissed: (_) {
                    Navigator.of(context).pop();
                  },
                  onUpdate: (DismissUpdateDetails details){
                    if( details.progress <= 0 ){
                      setState(() => isHoldingStoryDialog = false );
                    }
                    if( details.progress > 0 && isHoldingStoryDialog == false ){
                      setState(() => isHoldingStoryDialog = true );
                    }
                  },
                  key: const Key("key"),
                  child: PreviewStories(
                    whoIm : 'self',
                    onHold: isHoldingStoryDialog,
                    storiesList: myStories,
                    username: currentUser['username'],
                    avatarType : currentUser['avatar_type'],
                    avatarUrl: currentUser['avatar_url'],
                    onAction: ( dynamic value ) async {
                      if( value == null ){
                        Navigator.of(context).pop();
                      }else{
                        if( value['action'] == 'delete' ){
                          setState( () => myStories.removeWhere((element) => element['_id'] == value['_id']) );
                          final response = await userManager.deleteMyStories(currentUser['uid'], value['_id'], value['url']);
                          if( response['status'] == false ){
                            debugPrint( response['message'].toString() );
                          }
                          refreshState();
                        }
                      }
                    },
                    onReportAction: (dynamic data ) async {
                      Navigator.of(context).pop();
                      // if( data['action'] == 'vanish_user' ){
                      //   // {action: vanish_user, username: demo}
                      // }
                      // else if( data['action'] == 'report_user' ){
                      //   // {action: report_user, username: demo, reason: ddwdwew, storyId: }
                      // }
                      // else if( data['action'] == 'report_story' ){
                      //   // {action: report_story, username: demo, reason: fdfdfdfd, storyId: 64d09d7c5e3a5ce02494fe48}
                      // }
                    }
                  )
              );
            }
          );
        }
    );
  }

  void refreshState(){
    if( mounted ){
      setState(() {});
    }
  }

  /// UPLOAD STORY
  /// This function uploads the story image
  Future<void> _uploadStory( dynamic image, dynamic caption ) async {
    try{
      List<String> videoExtensions = ['.mov', '.mp4', '.webm', '.ogg', '.avi', '.flv', '.mpg', '.mpeg'];
      //List<String> imageExtensions = ['.jpg', '.jpeg', '.gif', '.png', '.raw', '.bmp', '.tif', '.tiff'];
      String mediaType = 'image';

      String ext = path.extension( ( image as File ).path );
      if( videoExtensions.contains( ext.toLowerCase() ) ){
        mediaType = 'video';
      }
      if( mediaType == 'video' ){
        return;
      }

      setState(() { isSavingStory = true; });
      // COMPRESS IMAGE
      File? compressedImageFile = await UtilityService().compressAndConvertToFile(image);
      if( compressedImageFile == null ){
        image = image;
      }else {
        image = compressedImageFile;
      }
      final response = await userManager.createStory(image, caption, mediaType, currentUser['uid']);
      if( response['status'] && mounted ){
        setState(() {
          myStories.add( response['story'] );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text( LanguageNotifier.of(context)!.translate('story_added_successfully') ),
          ),
        );
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text( response['message'] ),
          ),
        );
      }
      if( mounted ){
        setState(() { isSavingStory = false; });
      }
    } catch( e ){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text( e.toString() ),
        ),
      );
      setState(() { isSavingStory = false; });
    }
  }

  @override
  void dispose() {

    WidgetsBinding.instance.removeObserver(this);
    _captionController.dispose();
    _storyCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    bool isRTL() => Directionality.of(context).index != 0;
    String username = (currentUser != null) ? currentUser['username'] : '';
    TextEditingController usernameController =
        TextEditingController(text: username);
    TextEditingController statusController = TextEditingController(
      text: '${LanguageNotifier.of(context)!.translate(selectedStatus+'_abbr')} $selectedStatusText'
    );

    return Consumer2<PermissionManager, LocationManager>(
      builder: (context, permissionManager, locationManager, child) {

        return WillPopScope(
          onWillPop: () async => false,
          child: Stack(
            children: [
              Positioned.fill(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Scaffold(
                      backgroundColor: myColors.appSecBgColor,
                      appBar: AppBar(
                        backgroundColor: myColors.appSecBgColor,
                        leading: Container(),
                        actions: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                LanguageNotifier.of(context)!.translate(
                                    'lang_en'),
                                style: TextStyle(
                                    color: myColors.appSecTextColor),
                              ),
                              const SizedBox(width: 8.0),
                              FlutterSwitch(
                                  width: 50,
                                  height: 25,
                                  toggleSize: 20.0,
                                  borderRadius: 20.0,
                                  toggleColor: myColors.brandColor!,
                                  switchBorder:
                                  Border.all(
                                      width: 0, color: myColors.borderColor!),
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white,
                                  value: (selectedLang == 'en')
                                      ? false
                                      : true,
                                  onToggle: (value) async {
                                    if (selectedLang == 'en') {
                                      selectedLang = 'ar';
                                    } else {
                                      selectedLang = 'en';
                                    }
                                    setState(() {
                                      widget.onSetLocale();
                                    });
                                  }),
                              const SizedBox(width: 8.0),
                              Text(
                                LanguageNotifier.of(context)!.translate(
                                    'lang_ar'),
                                style: TextStyle(
                                    color: myColors.appSecTextColor),
                              ),
                              const SizedBox(width: 15.0)
                            ],
                          )
                        ],
                        elevation: 0.2,
                      ),
                      body: SingleChildScrollView(
                        //padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 0.0),
                        child: Directionality(
                          textDirection: isRTL()
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          child: Column(
                            children: <Widget>[

                              /// PERSONAL INFO
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Container(
                                  padding: const EdgeInsets.all(15.0),
                                  margin: const EdgeInsets.fromLTRB(
                                      15, 15, 15, 5),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(15)),
                                    border: Border.all(
                                        width: 1,
                                        color: myColors.borderColor!
                                            .withOpacity(0.5)),
                                  ),
                                  child: (currentUser != null)
                                      ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Stack(
                                        children: [
                                          (myStories.isNotEmpty) ?
                                          AnimatedContainer(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                begin: getAlignments[counterAnimator % getAlignments.length],
                                                end: getAlignments[(counterAnimator + 1) % getAlignments.length],
                                                colors: getColorsList,
                                                tileMode: TileMode.clamp,
                                              ),
                                            ),
                                            duration: const Duration(seconds: 1),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3.5),
                                              child:   (selectedImage['type'] == 'network') ?
                                              UserAvatar(
                                              url: userManager.getServerUrl('/')
                                                  .toString() +
                                                  selectedImage['url'],
                                              type: 'network',
                                              radius: 55)
                                              : UserAvatar(
                                                  url: selectedImage['url'],
                                                  type: 'avatar',
                                                  radius: 55
                                              ),
                                            ),
                                          )

                                              :
                                          Container(
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child:  (_profileImage != null) ? UserAvatar(
                                                url: '',
                                                file: _profileImage,
                                                type: 'selected',
                                                radius: 55,
                                              ) : (selectedImage['type'] == 'network') ?
                                              UserAvatar(
                                                  url: userManager.getServerUrl('/').toString()+selectedImage['url'],
                                                file: _profileImage,
                                                  type: 'network',
                                                  radius: 55,
                                              ) :
                                              UserAvatar(
                                                  url: selectedImage['url'],
                                                  type: 'avatar',
                                                  radius: 55
                                              ),
                                            ),
                                          ) ,
                                          Positioned(
                                            bottom: 10,
                                            left: 45,
                                            child: SvgPicture.asset(
                                              'assets/upload_img.svg',
                                              width: 20,
                                              colorFilter: const ColorFilter
                                                  .mode(
                                                  Colors.white,
                                                  BlendMode.srcIn),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: DropdownButton(
                                                isExpanded: false,
                                                underline: Container(),
                                                borderRadius: const BorderRadius
                                                    .all(
                                                    Radius.circular(8)),
                                                items: (myStories.isNotEmpty) ?
                                                [
                                                  DropdownMenuItem<String>(
                                                    value: 'gallery',
                                                    child: Container(
                                                      alignment: Alignment
                                                          .centerLeft,
                                                      decoration: const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Colors
                                                                .black12,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: <Widget>[
                                                          SvgPicture.asset(
                                                            'assets/upload_img.svg',
                                                            width: 20,
                                                            colorFilter: ColorFilter
                                                                .mode(
                                                                myColors
                                                                    .appSecTextColor!,
                                                                BlendMode
                                                                    .srcIn),
                                                          ),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'from_gallery')),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'camera',
                                                    child: Container(
                                                      alignment: Alignment
                                                          .centerLeft,
                                                      decoration: const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Colors
                                                                .black12,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: <Widget>[
                                                          const Icon(Icons
                                                              .camera_alt_outlined),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'take_photo')),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'add_to_story',
                                                    child: Container(

                                                      alignment: Alignment
                                                          .centerLeft,
                                                      decoration: (myStories.isNotEmpty)
                                                          ? const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Colors
                                                                .black12,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ) : const BoxDecoration(),
                                                      child: Row(
                                                        children: <Widget>[
                                                          const Icon(Icons.access_time_sharp),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'add_to_story')),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'view_story',
                                                    child: Container(
                                                      alignment: Alignment
                                                          .centerLeft,

                                                      child: Row(
                                                        children: <Widget>[
                                                          const Icon(Icons.remove_red_eye_outlined),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'view_story')),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                ]
                                                : [
                                                  DropdownMenuItem<String>(
                                                    value: 'gallery',
                                                    child: Container(
                                                      alignment: Alignment
                                                          .centerLeft,
                                                      decoration: const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Colors
                                                                .black12,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: <Widget>[
                                                          SvgPicture.asset(
                                                            'assets/upload_img.svg',
                                                            width: 20,
                                                            colorFilter: ColorFilter
                                                                .mode(
                                                                myColors
                                                                    .appSecTextColor!,
                                                                BlendMode
                                                                    .srcIn),
                                                          ),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'from_gallery')),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'camera',
                                                    child: Container(
                                                      alignment: Alignment
                                                          .centerLeft,
                                                      decoration: const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Colors
                                                                .black12,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: <Widget>[
                                                          const Icon(Icons
                                                              .camera_alt_outlined),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'take_photo')),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  DropdownMenuItem<String>(
                                                    value: 'add_to_story',
                                                    child: Container(

                                                      alignment: Alignment
                                                          .centerLeft,
                                                      decoration: (myStories.isNotEmpty)
                                                          ? const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: Colors
                                                                .black12,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ) : const BoxDecoration(),
                                                      child: Row(
                                                        children: <Widget>[
                                                          const Icon(Icons.access_time_sharp),
                                                          const SizedBox(
                                                            width: 15.0,
                                                          ),
                                                          Text(LanguageNotifier
                                                              .of(
                                                              context)!
                                                              .translate(
                                                              'add_to_story')),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                  // DropdownMenuItem<String>(
                                                  //   value: 'avatar',
                                                  //   child: Container(
                                                  //     alignment: Alignment.centerLeft,
                                                  //     decoration: const BoxDecoration(
                                                  //       border: Border(
                                                  //         bottom: BorderSide(
                                                  //           color: Colors.black12,
                                                  //           width: 1,
                                                  //         ),
                                                  //       ),
                                                  //     ),
                                                  //     child: Row(
                                                  //       children: <Widget>[
                                                  //         SvgPicture.asset(
                                                  //           'assets/avatar.svg',
                                                  //           width: 20,
                                                  //           colorFilter: ColorFilter.mode(
                                                  //               myColors
                                                  //                   .appSecTextColor!,
                                                  //               BlendMode.srcIn),
                                                  //         ),
                                                  //         const SizedBox(
                                                  //           width: 15.0,
                                                  //         ),
                                                  //         Text(
                                                  //           LanguageNotifier.of(
                                                  //               context)!
                                                  //               .translate(
                                                  //               'choose_avatar'),
                                                  //         )
                                                  //       ],
                                                  //     ),
                                                  //   ),
                                                  // ),
                                                onChanged: (value) {
                                                  if (value == 'gallery') {
                                                    _getImage(
                                                        ImageSource.gallery);
                                                  } else
                                                  if (value == 'camera') {
                                                    showCameraDialog(
                                                        context, _uploadImage);
                                                    //_getImage(ImageSource.camera);
                                                  } else
                                                  if (value == 'avatar') {
                                                    goToAvatarPage();
                                                  } else
                                                    if (value == 'add_to_story') {
                                                      showCameraDialog(
                                                          context, _previewNewStoryDialog,
                                                          showGallery: true);
                                                    } else
                                                      if (value == 'view_story') {
                                                        _viewMyStoriesDialog();
                                                      }
                                                },
                                              ),
                                            ),
                                          ),
                                          (isSavingAvatar) ?  Positioned(
                                              top: 35,
                                              left: 35,
                                              child: Center(
                                                child: CircularProgressIndicator(color: myColors.brandColor!),
                                              )
                                          ) : const SizedBox()
                                        ],
                                      ),
                                      const SizedBox(
                                        width: 15.0,
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.topRight,
                                          child: Column(
                                            children: [
                                              TextFormField(
                                                enabled: false,
                                                controller: usernameController,
                                                style: const TextStyle(
                                                    fontSize: 16.0,
                                                    height: 1.0),
                                                decoration: InputDecoration(
                                                  labelText:
                                                  LanguageNotifier.of(context)!
                                                      .translate('username'),
                                                  enabledBorder: UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: myColors
                                                            .borderColor!
                                                            .withOpacity(0.5)),
                                                  ),
                                                  disabledBorder:
                                                  const UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: Colors
                                                            .transparent),
                                                  ),
                                                  focusedBorder: UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: myColors
                                                            .borderColor!
                                                            .withOpacity(0.5)),
                                                  ),
                                                  //border: const OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                onChanged: (value) {},
                                              ),
                                              const SizedBox(height: 10),
                                              Stack(
                                                children: [
                                                  TextFormField(
                                                    controller: statusController,
                                                    enabled: false,
                                                    style: const TextStyle(
                                                        fontSize: 16.0,
                                                        height: 1.0),
                                                    decoration: InputDecoration(
                                                      labelText:
                                                      LanguageNotifier.of(
                                                          context)!
                                                          .translate('status'),
                                                      enabledBorder:
                                                      UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: myColors
                                                                .borderColor!
                                                                .withOpacity(
                                                                0.5)),
                                                      ),
                                                      disabledBorder:
                                                      const UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: Colors
                                                                .transparent),
                                                      ),
                                                      focusedBorder:
                                                      UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color: myColors
                                                                .borderColor!
                                                                .withOpacity(
                                                                0.5)),
                                                      ),
                                                      //border: const OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                                    onChanged: (value) {},
                                                  ),
                                                  Positioned(
                                                      top: -13,
                                                      left: 30,
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          size: 18,),
                                                        onPressed: () =>
                                                            _showPreviewDialog(
                                                                context),
                                                      ))
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                      : Center(
                                    child: CircularProgressIndicator(color: myColors.brandColor!),
                                  ),
                                ),
                              ),
                              /// MESSENGER
                              ListTile(
                                title: Row(
                                  children: <Widget>[
                                    SvgPicture.asset(
                                      'assets/message_icon.svg',
                                      width: 20,
                                      colorFilter: ColorFilter.mode(
                                          myColors.appSecTextColor!,
                                          BlendMode.srcIn),
                                    ),
                                    const SizedBox(width: 15.0),
                                    Text(
                                        LanguageNotifier.of(context)!.translate(
                                            'messenger')),
                                  ],
                                ),
                                onTap: () => Navigator.pushNamedAndRemoveUntil(
                                  context, '/messages',
                                  ModalRoute.withName('/home'),),
                              ),
                              /// VANISHED LIST
                              ListTile(
                                title: Row(
                                  children: <Widget>[
                                    SvgPicture.asset(
                                      'assets/vanish_icon.svg',
                                      width: 20,
                                      colorFilter: ColorFilter.mode(
                                          myColors.appSecTextColor!,
                                          BlendMode.srcIn),
                                    ),
                                    const SizedBox(width: 15.0),
                                    Text(LanguageNotifier.of(context)!
                                        .translate('vanished_list')),
                                  ],
                                ),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/block-list'),
                              ),
                              /// THEME TOGGLE
                              ListTile(
                                title: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/theme_icon.svg',
                                      width: 20,
                                      colorFilter: ColorFilter.mode(
                                          myColors.appSecTextColor!,
                                          BlendMode.srcIn),
                                    ),
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
                                        value: widget.theme.isLightMode,
                                        onToggle: (value) {
                                          if (value) {
                                            widget.theme.setLightMode();
                                          } else {
                                            widget.theme.setDarkMode();
                                          }
                                        }),
                                  ],
                                ),
                              ),
                              /// SETTINGS
                              ListTile(
                                title: Row(
                                  children: <Widget>[
                                    const SizedBox(
                                        width: 20,
                                        child: Icon(Icons.settings_outlined)
                                    ),
                                    const SizedBox(width: 15.0),
                                    Text(LanguageNotifier.of(context)!.translate('settings')),
                                  ],
                                ),
                                onTap: () => Navigator.pushNamed(context, '/settings'),
                              ),
                              /// LOGOUT
                              ListTile(
                                title: Row(
                                  children: <Widget>[
                                    SvgPicture.asset(
                                      'assets/logout_icon.svg',
                                      width: 20,
                                      colorFilter: ColorFilter.mode(
                                          myColors.appSecTextColor!,
                                          BlendMode.srcIn),
                                    ),
                                    const SizedBox(width: 15.0),
                                    Text(
                                        LanguageNotifier.of(context)!.translate(
                                            'logout')),
                                  ],
                                ),
                                onTap: () async {
                                  showDialog(
                                      barrierDismissible: false,
                                      context: context,
                                      builder: (context) =>
                                          CupertinoAlertDialog(
                                              title: Text(LanguageNotifier.of(context)!.translate('confirmation')),
                                              content: Text(LanguageNotifier.of(context)!.translate('logout_cfn_msg')),
                                              //actionsAlignment: MainAxisAlignment.spaceBetween,
                                              actions: <Widget>[
                                                // TextButton(
                                                //   child: Text(LanguageNotifier.of(context)!.translate('cancel'), style: TextStyle(color: myColors.appSecTextColor), ),
                                                //   onPressed: () async {
                                                //     Navigator.of(context).pop();
                                                //   },
                                                // ),
                                                // FilledButton(
                                                //   child: Text(LanguageNotifier.of(context)!.translate('yes')),
                                                //   onPressed: () async {
                                                //     String uid = currentUser['uid'];
                                                //     await StorageManager
                                                //         .deleteUser();
                                                //     if (ss.socket.connected &&
                                                //         uid.isNotEmpty) {
                                                //       ss.socket.emit(
                                                //           'clear-chats',
                                                //           { "uid": uid});
                                                //       ss.socket.emit(
                                                //           'set-user-status', {
                                                //         "uid": uid,
                                                //         "status": false
                                                //       });
                                                //       ss.socket
                                                //           .clearListeners();
                                                //       ss.socket.disconnect();
                                                //       ss.socket.dispose();
                                                //     }
                                                //     if (mounted) {
                                                //       Navigator.of(context)
                                                //           .pushAndRemoveUntil(
                                                //           MaterialPageRoute(
                                                //               builder: (
                                                //                   context) => const SignIn()),
                                                //               (Route<
                                                //               dynamic> route) => false);
                                                //     }
                                                //   },
                                                // ),
                                                CupertinoDialogAction(
                                                  child: Text(
                                                    LanguageNotifier.of(
                                                        context)!.translate(
                                                        'no'),
                                                    style: const TextStyle(
                                                        color: Colors.red),),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                CupertinoDialogAction(
                                                  child: Text(
                                                      LanguageNotifier.of(
                                                          context)!.translate(
                                                          'yes'),
                                                      style: TextStyle(
                                                          color: myColors
                                                              .brandColor!)),
                                                  onPressed: () async {
                                                    String uid = currentUser['uid'];
                                                    await StorageManager
                                                        .deleteUser();
                                                    if (ss.socket.connected &&
                                                        uid.isNotEmpty) {
                                                      ss.socket.emit(
                                                          'clear-chats',
                                                          { "uid": uid});
                                                      ss.socket.emit(
                                                          'set-user-status', {
                                                        "uid": uid,
                                                        "status": false
                                                      });
                                                      ss.socket
                                                          .clearListeners();
                                                      ss.socket.disconnect();
                                                      ss.socket.dispose();
                                                    }
                                                    if (mounted) {
                                                      Navigator.of(context)
                                                          .pushAndRemoveUntil(
                                                          MaterialPageRoute(
                                                              builder: (
                                                                  context) => const SignIn()),
                                                              (Route<
                                                              dynamic> route) => false);
                                                    }
                                                  },
                                                ),
                                              ]
                                          )
                                  );
                                },
                              ),
                              /// SOCIAL ICONS
                              ListTile(
                                title: Row(
                                  children: [
                                    IconButton(
                                        onPressed: () {},
                                        icon: Image.asset(
                                          'assets/facebook.png',
                                          width: 30,
                                        )),
                                    IconButton(
                                        onPressed: () {},
                                        icon: Image.asset(
                                          'assets/instagram.png',
                                          width: 30,
                                        )),
                                    IconButton(
                                        onPressed: () {},
                                        icon: Image.asset(
                                          'assets/twitter.png',
                                          width: 30,
                                        )),
                                  ],
                                ),
                              ),
                              /// TERMS & CONDITIONS
                              ListTile(
                                title: Text(
                                    LanguageNotifier.of(context)!.translate(
                                        'toc')),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/toc'),
                              ),
                              /// PRIVACY POLICY
                              ListTile(
                                title: Text(
                                    LanguageNotifier.of(context)!.translate(
                                        'privacy_policy')),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/privacy-policy'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      bottomNavigationBar: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(25), topLeft: Radius
                              .circular(25)),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                spreadRadius: 0,
                                blurRadius: 10),
                          ],
                          color: myColors.appSecBgColor,
                        ),
                        //notchedShape: CircularNotchedRectangle(),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              decoration: BoxDecoration(
                                color: myColors.brandColor,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween,
                                children: <Widget>[
                                  // Consumer<ChatManager>(
                                  //   builder: (context, chat, child) {
                                  //     print(chat.counter);
                                  //     return Text('');
                                  //   }
                                  // ),
                                  badges.Badge(
                                    badgeStyle: const badges.BadgeStyle(
                                      badgeColor: Colors.red,
                                    ),
                                    showBadge: (chatCounter > 0) ? true : false,
                                    position: badges.BadgePosition.topEnd(
                                        top: 5, end: 0),
                                    badgeContent: Text(chatCounter.toString(),
                                      style: const TextStyle(
                                          color: Colors.white),),
                                    child: IconButton(
                                      icon: SvgPicture.asset(
                                        'assets/speech.svg',
                                        colorFilter: const ColorFilter.mode(
                                            Colors.white, BlendMode.srcIn),
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamedAndRemoveUntil(
                                          context, '/messages',
                                          ModalRoute.withName('/home'),);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      // StorageManager.saveData(
                                      //     'home-tab', (homeTab == 0) ? 1 : 0);
                                      Navigator.pop(context);
                                    },
                                    //icon: Icon(Icons.map_outlined, color: Colors.white,),
                                    icon: SvgPicture.asset(
                                      (homeTab == 1)
                                          ? 'assets/listview.svg'
                                          : 'assets/mapview.svg',
                                      colorFilter: const ColorFilter.mode(
                                          Colors.white, BlendMode.srcIn),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: null,
                                    //icon: Icon(Icons.person_outline_rounded, color: Colors.white,),
                                    icon: SvgPicture.asset(
                                      'assets/profile.svg',
                                      colorFilter: const ColorFilter.mode(
                                          Colors.white, BlendMode.srcIn),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
              ),
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (details.delta.dx > 10) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 30,
                    color: Colors.transparent,
                    height: MediaQuery
                        .of(context)
                        .size
                        .height,
                  ),
                ),
              ),
              ( (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? Positioned(
                  child: UtilityService().showLocationAlertDialog(
                      context,
                      currentUser,
                      refreshState,
                      type: 'permission',
                      privacyDisabled: locationManager.isPrivacyDisabled
                  )
              ) :
              (!locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? Positioned(
                  child: UtilityService().showLocationAlertDialog(context, currentUser, refreshState, privacyDisabled: locationManager.isPrivacyDisabled)
              ) :
              Container(),
            ],
          ),
        );
      }
    );
  }
}

/// IMAGE CONVERTER
/// This Class provides a function to convert the Memory image to File
class ImageConverter {
  static Future<File> convertMemoryImageToFile(MemoryImage memoryImage) async {
    final Uint8List bytes = memoryImage.bytes;
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    dynamic key = UniqueKey();
    final tempFile = File('$tempPath/$key.jpg');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }
}