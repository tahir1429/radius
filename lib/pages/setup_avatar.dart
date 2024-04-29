import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:radius_app/pages/avatars.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/widgets/camera.dart';
import 'package:custom_image_crop/custom_image_crop.dart';
import 'package:radius_app/services/locationManager.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/services/utlityService.dart';

class SetupAvatar extends StatefulWidget {
  const SetupAvatar({Key? key}) : super(key: key);

  @override
  State<SetupAvatar> createState() => _SetupAvatarState();
}

class _SetupAvatarState extends State<SetupAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  TextEditingController usernameController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  UserManager userManager = UserManager();
  final picker = ImagePicker();
  File? _image;
  String defaultAvatar = 'assets/app_icon.png';
  dynamic selectedImage = { "type" : "avatar", "url" : 'assets/app_icon.png'};
  bool showSpinner = false;

  dynamic currentUser;

  Timer? searchOnStoppedTyping;
  bool isUsernameValidated = false;
  bool isUsernameAvailable = true;
  bool isVerifyingUsername = false;
  CustomImageCropController controller = CustomImageCropController();

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() async {
    showSpinner = true;
    setState(() { });
    currentUser = await StorageManager.getUser();
    showSpinner = false;
    setState(() {});
  }

  Future<void> _getImage(ImageSource source) async {
    try{
      //final pickedFile = await picker.getImage(source: source);
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        _previewSelectedProfileImage( File(pickedFile.path) );
      } else {
        debugPrint('No image selected.');
      }
    }
    on PlatformException catch( e ){
      showCupertinoDialog(
        context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("Invalid/Corrupted Image"),
            content: Text(e.message.toString()),
            actions:  <Widget>[
              CupertinoDialogAction(
                child: const Text("Ok"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ]
          )
      );
      debugPrint( e.message );
    }
    catch( e ){
      debugPrint( e.toString() );
    }
  }

  void updateAvatarInformation(dynamic avatar) {
    selectedImage = { "type" : "avatar", "url" : avatar};
    setState(() {
      _image = null;
      defaultAvatar = avatar;
    });
  }

  void showCameraDialog( BuildContext context ){
    showGeneralDialog(
        context: context,
        barrierColor: Colors.black12.withOpacity(1),
        pageBuilder: (_, __, ___) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
                builder: (context, setState ) {
                  return Consumer<PermissionManager>(
                      builder: (context, permissionManager, child) {
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Camera(
                                onSelectFile : ( XFile file ){
                                  setState( () {
                                    _previewSelectedProfileImage( File(file.path) );
                                  });
                                  Navigator.pop(context);
                                },
                                onSelect: ( XFile file, String type ){

                                },
                                showGallery: false,
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
                                actions: [
                                  Image.asset(
                                    'assets/app_icon.png',
                                    width: 40,
                                    height: 40,
                                    repeat: ImageRepeat.noRepeat,
                                    alignment: Alignment.center,
                                    color: Colors.white,
                                  ),
                                  const SizedBox( width: 20,)
                                ],
                              ),
                            ),
                            ( !permissionManager.isLocationPermissionGranted ) ?  Positioned(
                                child: UtilityService().showAlertDialog('', context, setState)
                            ) :
                            ( !permissionManager.isLocationServiceEnabled ) ?  Positioned(
                                child: UtilityService().showAlertDialog('', context, setState)
                            ) :
                            Container(),
                          ],
                        );
                      }
                  );
                }
            ),
          );
        }
    );
  }

  void _previewSelectedProfileImage( File image ){
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
                          child : _cropImage( image )
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
                            final MemoryImage? image = await controller.onCropImage();
                            File file = await ImageConverter.convertMemoryImageToFile(image!);
                            _refreshImage( file );
                            if( mounted ){
                              Navigator.of(context).pop();
                            }
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

  Widget _cropImage( File image ) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomImageCrop(
        backgroundColor: Colors.black,
        cropController: controller,
        image: FileImage(image), // Any Imageprovider will work, try with a NetworkImage for example...
        shape: CustomCropShape.Circle,
        cropPercentage: 0.8,
      ),
    );
  }

  _onChangeHandler( String value ) {
    if( !isUsernameValidated ){
      setState(() => {});
      return;
    }
    const duration = Duration(milliseconds:800); // set the duration that you want call search() after that.
    if (searchOnStoppedTyping != null) {
      searchOnStoppedTyping!.cancel();
      setState(() => {}); // clear timer
    }
    searchOnStoppedTyping = Timer(duration, () => checkUserName(value) );
    isVerifyingUsername = false;
    setState(() => {});
  }

  checkUserName( String username ) async {
    setState(() => isVerifyingUsername = true);
    final response = await userManager.isUsernameTaken(username);
    if( response['status'] ){
      isUsernameAvailable = !response['exist'];
    }else{
      isUsernameAvailable = false;
    }
    setState(() => isVerifyingUsername = false);
  }

  _refreshImage( File image ){
    setState(() {
      _image = image;
      selectedImage = { "type" : "network", "url" : '' };
      defaultAvatar = image.path;
    });
  }

  @override
  void dispose(){
    _controller.dispose();
    usernameController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    bool isRTL() => Directionality.of(context).index != 0;

    void goToAvatarPage() async {
      final information = await Navigator.push(
        context,
        CupertinoPageRoute(
            fullscreenDialog: true, builder: (context) => const Avatars()
        ),
      );
      if( information != null ){
        updateAvatarInformation(information);
      }
    }

    return Consumer<ThemeNotifier>(
        builder: (context, theme, _) => Scaffold(
          backgroundColor: myColors.appSecBgColor,
          body: ( !showSpinner ) ? Stack(
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: Image.asset((theme.isLightMode) ? 'assets/videos/4-light.gif' : 'assets/videos/4-dark.gif', color: Colors.white.withOpacity(0.8), colorBlendMode: BlendMode.modulate,),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 80, bottom: 50),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: Text('${LanguageNotifier.of(context)!.translate('welcome')} ${currentUser['fname']}!', style: const TextStyle(fontSize: 20),),),
                            const SizedBox(width: 5.0,),
                            InkWell(
                              onTap: () {
                                StorageManager.deleteUser();
                                Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (context) => const SignIn()),
                                        (Route<dynamic> route) => false);
                              },
                              child: Text(LanguageNotifier.of(context)!.translate('logout'), style: const TextStyle(color: Color(0xFFC835C1), fontWeight: FontWeight.w700),),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20,),
                        Center(
                          child: Text(LanguageNotifier.of(context)!.translate('choose_profile'), style: const TextStyle(fontSize: 16),),
                        ),
                        const SizedBox(height: 20,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: myColors.brandColor,
                                    borderRadius: BorderRadius.circular(120),
                                    border: Border.all(color: myColors.brandColor!),
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    backgroundImage: _image == null ? AssetImage(defaultAvatar) : FileImage(_image!) as ImageProvider,
                                    radius: 100.0,
                                  ),
                                ),
                                Positioned(
                                  right: ( isRTL() ) ? 15 : null,
                                  left: ( isRTL() ) ? null : 15,
                                  bottom: 0,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: DropdownButton(
                                      isExpanded: false,
                                      underline: Container(),
                                      icon: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: myColors.brandColor,
                                          borderRadius: BorderRadius.circular(100),
                                          border: Border.all(color: Colors.grey),
                                        ),
                                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white,),
                                      ),
                                      borderRadius: const BorderRadius.all(Radius.circular(15)),
                                      items: [
                                        // DropdownMenuItem<String>(
                                        //   value: 'avatar',
                                        //   child: Container(
                                        //     alignment: Alignment.centerLeft,
                                        //     decoration: const BoxDecoration(
                                        //       border: Border(
                                        //         bottom: BorderSide(
                                        //           color: Colors.black12,
                                        //           width: 2,
                                        //         ),
                                        //       ),
                                        //     ),
                                        //     child: Row(
                                        //       children: <Widget> [
                                        //         SvgPicture.asset(
                                        //           'assets/avatar.svg',
                                        //           width: 20,
                                        //           colorFilter: ColorFilter.mode(myColors.appSecTextColor!, BlendMode.srcIn),
                                        //         ),
                                        //         const SizedBox(width: 15.0,), Text(LanguageNotifier.of(context)!.translate('choose_avatar'),)
                                        //       ],
                                        //     ),
                                        //   ),
                                        //   // onTap: (){
                                        //   //   moveToSecondPage();
                                        //   // },
                                        // ),
                                        DropdownMenuItem<String>(
                                          value: 'gallery',
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.black12,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: <Widget> [
                                                SvgPicture.asset(
                                                  'assets/upload_img.svg',
                                                  width: 20,
                                                  colorFilter: ColorFilter.mode(myColors.appSecTextColor!, BlendMode.srcIn),
                                                ),
                                                const SizedBox(width: 15.0,), Text(LanguageNotifier.of(context)!.translate('from_gallery')),
                                              ],
                                            ),
                                          ),
                                          onTap: (){ _getImage( ImageSource.gallery ); },
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'camera',
                                          child: Row(
                                            children: <Widget> [ const Icon(Icons.camera_alt_outlined),  const SizedBox(width: 15.0,), Text(LanguageNotifier.of(context)!.translate('take_photo')) ],
                                          ),
                                        )
                                      ],
                                      onChanged: (value) {
                                        if( value == 'avatar' ){
                                          // Navigator.pushNamed(context, '/avatars');
                                          goToAvatarPage();
                                        }
                                        else if( value == 'camera' ){
                                          //showCameraDialog( context );
                                          _getImage( ImageSource.camera );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 30,),
                        /// USERNAME INPUT
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: usernameController,
                          keyboardType: TextInputType.text,
                          // textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            FilteringTextInputFormatter(RegExp(r'[A-Za-z0-9._]'), allow: true)
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            labelText:LanguageNotifier.of(context)!.translate('username'),
                            hintText: LanguageNotifier.of(context)!.translate('username_hint'),
                          ),
                          validator: ( value ){
                            if( value!.isEmpty ){
                              isUsernameValidated = false;
                              return LanguageNotifier.of(context)!.translate('error_username_required');
                            }
                            RegExp regexp = RegExp(r'^[A-Za-z0-9][a-z0-9._]*$');
                            if ( !regexp.hasMatch(value!)) {
                              isUsernameValidated = false;
                              return LanguageNotifier.of(context)!.translate('error_username_invalid');
                            }
                            isUsernameValidated = true;
                            return null;
                          },
                          onChanged: ( value ) => _onChangeHandler(value),
                        ),
                        const SizedBox(height: 10,),
                        Text(LanguageNotifier.of(context)!.translate('username_type')),
                        ( !isUsernameValidated ) ? Container() :
                        ( isVerifyingUsername )
                            ?
                        Container( padding: const EdgeInsets.only(top: 10), child: Row( children: [ const SizedBox(width: 20, height: 20, child: CircularProgressIndicator( strokeWidth: 3,), ), const SizedBox(width: 10), Text(LanguageNotifier.of(context)!.translate('verifying_username')) ], ),)
                            :
                        ( isUsernameAvailable )
                            ?
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0XFF75F876),
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                          ),
                          child: ( usernameController.text.isNotEmpty ) ? Row( children: [ const Icon(Icons.check), Text(LanguageNotifier.of(context)!.translate('success_username')) ], ) : Container(),
                        )
                            :
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Color(0XFFFF5757),
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                          ),
                          child: Row( children: [ const Icon(Icons.close), Text(LanguageNotifier.of(context)!.translate('error_username_taken'),) ], ),
                        ),
                        // Container(
                        //     padding: const EdgeInsets.symmetric(vertical: 10),
                        //     child: Row( children: [ const Icon(Icons.close, color: Colors.red,), Text(LanguageNotifier.of(context)!.translate('error_username_taken'), style: const TextStyle(color: Colors.red),) ], )
                        // ),
                        const SizedBox(height: 20,),
                        (!showSpinner) ? SizedBox(
                          width: MediaQuery.of(context).size.width*0.9,
                          child: FilledButton(
                              onPressed: () async {
                                if ( formKey.currentState!.validate() && isUsernameAvailable ) {
                                  setState(() => showSpinner = true);
                                  dynamic data = {
                                    'uid' : currentUser['uid'],
                                    'username' : usernameController.text,
                                    'avatar_type' : selectedImage['type'],
                                    'avatar_url' : selectedImage['url']
                                  };
                                  final response = await userManager.completeRegistration(data, _image);
                                  if( response['status'] && context.mounted ) {
                                    StorageManager.saveData('location-enabled', false );
                                    StorageManager.saveData('location-denied', false );
                                    StorageManager.saveData('privacy-disabled', false );
                                    StorageManager.saveUser( response['user'], jwtToken: response['token'] );
                                    Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
                                    Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( false );
                                    Navigator.pushNamed(context, '/home');
                                  }else{
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(response['message']),)
                                    );
                                  }
                                  setState(() => showSpinner = false);
                                }
                              },
                              child: Text(LanguageNotifier.of(context)!.translate('finish'))
                              ),
                        ) : Container(),
                        //const SizedBox(height: 20,),
                        // SizedBox(
                        //   width: MediaQuery.of(context).size.width*0.9,
                        //   child: FilledButton(
                        //     child: Text(LanguageNotifier.of(context)!.translate('finish'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
                        //     onPressed: () async {
                        //       setState(() => showSpinner = true);
                        //       var data = {};
                        //       data['avatar_type'] = selectedImage['type'];
                        //       data['avatar_url'] = selectedImage['url'];
                        //
                        //       final account = await userManager.register( data, _image );
                        //       if( account['status'] && context.mounted ) {
                        //         StorageManager.saveUser( account['user'], jwtToken: account['token'] );
                        //         Navigator.pushNamed(context, '/home');
                        //       }else{
                        //         ScaffoldMessenger.of(context).showSnackBar(
                        //             SnackBar(content: Text(account['message']),)
                        //         );
                        //       }
                        //       setState(() => showSpinner = false);
                        //       return;
                        //       // Create User
                        //       // final accountStatus = await userManager.register(data['email'], data['password']);
                        //       // if( accountStatus['status'] && context.mounted ){
                        //       //   // Add display name
                        //       //   await userManager.updateDisplayName(data['username']);
                        //       //   if( selectedImage['type'] == 'network' ){
                        //       //     String? url = await FirebaseStorageService.uploadImage(_image!, accountStatus['uid'] );
                        //       //     if (url != null && mounted ) {
                        //       //       data['avatar_type'] = 'network';
                        //       //       data['avatar_url'] = url;
                        //       //     }
                        //       //   }
                        //       //   // Add User
                        //       //   data['uid'] = accountStatus['uid'];
                        //       //   final response = await userManager.addUser(data['uid'], data['email'], data['username'], data['phone'], data['dob'], data['avatar_type'], data['avatar_url']);
                        //       //   if( response['status'] && context.mounted ){
                        //       //     final loggedIn = await userManager.login( data['email'], data['password'] );
                        //       //     if( loggedIn['status'] ){
                        //       //       User currentUser = await userManager.getCurrentUser();
                        //       //       dynamic user = await userManager.getUserInfo( currentUser.uid );
                        //       //       StorageManager.saveUser( user[0] );
                        //       //       if( mounted ){
                        //       //         Navigator.pushNamed(context, '/home');
                        //       //         return;
                        //       //       }
                        //       //     }
                        //       //     if( mounted ){
                        //       //       ScaffoldMessenger.of(context).showSnackBar(
                        //       //           const SnackBar(content: Text('Account created successfully'),)
                        //       //       );
                        //       //       Navigator.pushNamed(context, '/sign-in');
                        //       //     }
                        //       //   }else{
                        //       //     ScaffoldMessenger.of(context).showSnackBar(
                        //       //         SnackBar(content: Text(response['msg']),)
                        //       //     );
                        //       //   }
                        //       // }else{
                        //       //   ScaffoldMessenger.of(context).showSnackBar(
                        //       //       SnackBar(content: Text(accountStatus['error']),)
                        //       //   );
                        //       // }
                        //       // setState(() => showSpinner = false);
                        //       return;
                        //       //final response = await userManager.addUser(data['email'], data['username'], data['phone'], data['dob'], data['avatar_type'], data['avatar_url']);
                        //       // if( response['status'] && context.mounted ){
                        //       //   print(response);
                        //       // }else{
                        //       //   ScaffoldMessenger.of(context).showSnackBar(
                        //       //       SnackBar(content: Text(response['msg']),)
                        //       //   );
                        //       // }
                        //     },
                        //   ),
                        // )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ) : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 100,
                    height: 100,
                    repeat: ImageRepeat.noRepeat,
                    alignment: Alignment.center,
                    color: ( theme.isLightMode ) ? Colors.black : Colors.white,
                  ),
                ),
                const SizedBox(height: 20,),
                Text(LanguageNotifier.of(context)!.translate('applying_changes'), style: const TextStyle(fontSize: 18),)
              ],
            ),
          ),
          // floatingActionButton: ( !showSpinner) ? Container(
          //   padding: const EdgeInsets.only(bottom: 20.0),
          //   width: MediaQuery.of(context).size.width*0.9,
          //   child: FloatingActionButton.extended(
          //     backgroundColor: myColors.brandColor,
          //     foregroundColor: Colors.white,
          //     shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(10)
          //     ),
          //     onPressed: () async {
          //       if ( formKey.currentState!.validate() && isUsernameAvailable ) {
          //         setState(() => showSpinner = true);
          //         dynamic data = {
          //           'uid' : currentUser['uid'],
          //           'username' : usernameController.text,
          //           'avatar_type' : selectedImage['type'],
          //           'avatar_url' : selectedImage['url']
          //         };
          //         final response = await userManager.completeRegistration(data, _image);
          //         if( response['status'] && context.mounted ) {
          //           StorageManager.saveUser( response['user'], jwtToken: response['token'] );
          //           Navigator.pushNamed(context, '/home');
          //         }else{
          //           ScaffoldMessenger.of(context).showSnackBar(
          //               SnackBar(content: Text(response['message']),)
          //           );
          //         }
          //         setState(() => showSpinner = false);
          //       }
          //     },
          //     label: Text(LanguageNotifier.of(context)!.translate('finish')),
          //   )
          // ) : Container(),
        ),
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
