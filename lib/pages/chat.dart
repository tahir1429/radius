import 'dart:async';
import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/locationManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/services/chatService.dart';
import 'package:radius_app/widgets/camera.dart';
import 'package:http/http.dart' as http;
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:radius_app/widgets/userAvatar.dart';

import '../services/permissionManager.dart';
import '../widgets/previewStories.dart';

class Chat extends StatefulWidget {
  final dynamic currentUser;
  final dynamic receiverUserId;
  const Chat({Key? key, required this.currentUser, required this.receiverUserId}) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver{

  UserManager userManager = UserManager();
  UtilityService utilityService = UtilityService();
  ChatService chatService = ChatService();
  final ScrollController _controller = ScrollController();
  final SocketSingleton ss = SocketSingleton();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final picker = ImagePicker();
  File? _image;

  dynamic currentUser;
  dynamic otherUser;
  double distance = 0.0; // Distance in meters
  Color? background;
  dynamic conversation;
  bool isHoldingStoryDialog = false;

  Timer? timer;
  Timer? readTimer;
  /// RADIUS DEFINED BY ADMIN
  double radiusInMeters = 100.0;
  /// LOADERS
  bool isLoadingChat = false;
  bool isSendingMessage = false;
  /// CHECK - IS CURRENT USER IS BLOCKED
  bool isBlocked = false;
  /// SHOW MESSAGE TIME FOR DEFINED PERIOD
  late RestartableTimer showSentTime;
  int showSentTimeIndex = -1;
  bool isCameraOn = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });
    initActivity( widget.receiverUserId );
    timer = Timer.periodic(const Duration( seconds: 5 ), (Timer t) => _getCurrentLocation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        initActivity( widget.receiverUserId );
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // TODO: Handle this case.
        break;
      case AppLifecycleState.detached:
        // TODO: Handle this case.
        break;
    }
  }

  /// GET CURRENT USER LOCATION & CHECK IF EXIST IN RADIUS
  /// CALLS RECURSIVELY AFTER DEFINED PERIOD (20 SECONDS)
  Future<void> _getCurrentLocation() async {
    try{
      bool isLocationServiceEnabled  = await Geolocator.isLocationServiceEnabled();
      if( isLocationServiceEnabled ){
        final position = await Geolocator.getCurrentPosition(
            forceAndroidLocationManager: true,
            desiredAccuracy: LocationAccuracy.high
        );
        LatLng pos = LatLng( position!.latitude, position!.longitude );
        // UPDATE CURRENT USER COORDINATES
        currentUser['location']['coordinates'] = [ pos.longitude, pos.latitude ];
        // GET OTHER USER
        final response = await userManager.getUserBy( id: otherUser['_id'] );
        if( response['status'] ){
          otherUser = response['user'];
        }
        final otherUserCoordinates = otherUser['location']['coordinates'];
        // CALCULATE DISTANCE
        final distance = utilityService.calculateDistanceInMeters(
          pos.latitude,
          pos.longitude,
          otherUserCoordinates[1],
          otherUserCoordinates[0],
        );
        final double userRadius = double.parse( distance.toString() );
        if( radiusInMeters < userRadius && mounted ){
          Navigator.popAndPushNamed(context, '/messages');
        }else{
          calculateProperties();
        }
      }else{
        debugPrint( 'Location service is disabled' );
      }
    }catch (e) {
      debugPrint( 'CHAT _getCurrentLocation ERROR: ${e.toString()}' );
    }
  }

  /// INITIALIZE/START ACTIVITY
  /// @param uid - Other User ID
  void initActivity( String uid ) async {
    // GET RADIUS DEFINED BY ADMIN FROM STORAGE
    radiusInMeters = await StorageManager.readData('radius');
    // GET CURRENT USER FROM STORAGE
    currentUser = await StorageManager.getUser();
    // SHOW LOADER
    setState(() { isLoadingChat = true; });
    // GET OTHER USER
    final response = await userManager.getUserBy( id: uid );
    if( response['status'] ){
      otherUser = response['user'];
      // [CHECK] - IF BLOCKED BY OTHER USER
      List blockedBy = otherUser['blockedBy'] ?? [];
      if( blockedBy.contains( currentUser['uid'] ) ){
        if( mounted ){
          setState(() {
            isBlocked = true;
            isLoadingChat = false;
          });
        }
        return;
      }
      // [CHECK] - IF OTHER USER IS ONLINE
      bool isOnline = otherUser['isOnline'] ?? false;
      if( !isOnline && mounted ){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar( content: Text(LanguageNotifier.of(context)!.translate('user_offline')), ),
        );
        Navigator.pop(context);
        return;
      }
      // [CHECK] - IF NOT BLOCKED BY OTHER USER
      if( !isBlocked && mounted ){
        // [CHECK] - IF SOCKET IS CONNECTED
        if( ss.socket.connected ){
          final data = {
            "createdBy" : currentUser['uid'],
            "members"   : [ currentUser['uid'], otherUser['_id'] ],
            "memberInfo": [
              {
                "uid" : otherUser['_id'],
                "username" : otherUser['username']
              }
            ],
          };
          // FIND CHAT
          ss.socket.emitWithAck('get-single-chat', data, ack : ( response ){
            if( response['status'] ){
              conversation = response['chat'];
              _markChatAsRead();
              setState(() {
                isLoadingChat = false;
              });
              if( (response['chat']['messages'] as List).isNotEmpty ){
                Future.delayed(const Duration(microseconds: 10000), () {
                  _scrollDown();
                });
              }
            }else{
              debugPrint( response['error'] );
            }
          });
          // [EVENT] - On New Message
          ss.socket.on('new-message', ( data ){
            if( mounted && conversation!= null && data['chatId'] == conversation['_id'] ){
              // CHECK IF SAME TEXT IS BEING RETURNED TWICE.
              bool isExist = ( conversation['messages'] as List ).contains( data['message'] );
              if( !isExist && mounted ){
                setState(() {
                  ( conversation['messages'] as List ).add( data['message'] );
                });
                Future.delayed(const Duration( microseconds: 100 ), () {
                  _scrollDown();
                  _markChatAsRead();
                });
              }
            }
          });
          // [EVENT] - On Message Seen
          ss.socket.on('seen-msg', ( data ){
            if( mounted && conversation!= null && data['chat']['_id'] == conversation['_id'] ){
              setState(() {
                conversation = data['chat'];
              });
              Future.delayed(const Duration( microseconds: 100 ), () {
                _scrollDown();
              });
            }
          });
          // [EVENT] - ON CHAT DELETED
          ss.socket.on('chat-deleted', (data){
            if( mounted && conversation != null && conversation['_id'] == data['chatId'] ){
              setState(() {
                conversation = null;
              });
              // ScaffoldMessenger.of(context).showSnackBar(
              //     SnackBar(content: Text(LanguageNotifier.of(context)!.translate('chat_removed')),)
              // );
              Navigator.of(context).pop();
            }
          });
          // [EVENT] - ON BLOCKED BY END-USER
          ss.socket.on('blocked', (data){
            if( mounted && data['byId'] == otherUser['uid'] && data['selfId'] == currentUser['uid'] ){
              setState(() {
                isBlocked = true;
              });
            }
          });
          /// EVENT: ON SOCKET CONNECTED/RECONNECTED/DISCONNECTED
          /// Re-build the activity
          SocketSingleton().listenToEvent('connect', (data) {
            initActivity( widget.receiverUserId );
          });
          SocketSingleton().listenToEvent('reconnect', (data) {
            initActivity( widget.receiverUserId );
          });
          SocketSingleton().listenToEvent('disconnect', (data) {
            setState(() => {});
          });
        }
        else{
          ss.socket.connect();
          SocketSingleton().listenToEvent('connect', (data) {
            initActivity( widget.receiverUserId );
          });
          debugPrint('Socket Disconnected');
        }
        calculateProperties();
        setState(() {
          isLoadingChat = false;
        });
        Future.delayed(const Duration( seconds: 2 ), () {
          _scrollDown();
        });
      }
    }else{
      setState(() { isLoadingChat = false; });
    }
  }

  /// CALCULATE DISTANCE & SET COLOR PROPERTIES
  void calculateProperties(){
    if( mounted ){
      setState(() {
        final currentUserCoordinates = currentUser['location']['coordinates'];
        final otherUserCoordinates = otherUser['location']['coordinates'];
        /// Calculate distance
        distance = utilityService.calculateDistanceInMeters(
          currentUserCoordinates[1],
          currentUserCoordinates[0],
          otherUserCoordinates[1],
          otherUserCoordinates[0],
        );
        /// Check Color
        if( (distance/radiusInMeters) < 0.33 ){
          background = Colors.green;
        }
        else if( (distance/radiusInMeters) < 0.66 ){
          background = Colors.yellow;
        }
        else if( (distance/radiusInMeters) < 1 ){
          background = Colors.red;
        }else{
          background = Colors.red;
        }
      });
    }
  }

  void _scrollDown() {
    try{
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: const Duration(microseconds: 1),
        curve: Curves.linear,
      );
    }catch( e ){
      debugPrint( e.toString() );
    }
  }

  Widget _buildChat() {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return ( isLoadingChat ) ?
      Center(child: CircularProgressIndicator( color: myColors.brandColor! )) :
      ( conversation == null || conversation['messages'].length == 0 ) ?
        Center(child: Text( LanguageNotifier.of(context)!.translate('no_msg_found') )) :
        ListView.builder(
          controller: _controller,
          itemCount: conversation['messages'].length ?? 0, // assuming you have a list of chat messages
          itemBuilder: (context, index) {
            dynamic message = conversation['messages'][index];
            bool isNextSame = false;
            if( index < conversation['messages'].length-1 ){
              dynamic nextMessage = conversation['messages'][index+1] ?? false;
              isNextSame = ( message['sender'] == nextMessage['sender'] ) ? true : false;
            }
            return _buildChatItem( message, index, isNextSame );
          },
        );
  }

  Widget _buildChatItem(dynamic message, int index, bool isNextSame ) {
    return ( message['sender'] == currentUser['uid'] ) ? _sender( message, index, isNextSame) : _receiver( message, index, isNextSame );
  }

  void loadImagesInBG( url ){
    UserAvatar(url: userManager.getServerUrl('/').toString()+url, type: 'network', radius: 0);
  }

  Widget _sender( dynamic message, int index, bool isNextSame ){
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    double currentScreenWidth = MediaQuery.of(context).size.width*0.8;
    String formattedDate = UtilityService().getTextSentDateTime( message['timestamp']  );
    bool isTimeInSameRow = ( message['text'].toString().length < 20 ) ? true : false;
    if( message['attachment'] != '' ){
      loadImagesInBG( message['attachment'] );
    }

    return GestureDetector(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                //minWidth: message['text'].toString().length.toDouble()+150,
                  maxWidth: currentScreenWidth - 50
              ),
              decoration: BoxDecoration(
                border: Border.all(color: myColors.brandColor!),
                color: myColors.brandColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                  topRight: (isNextSame) ? Radius.circular(15) : Radius.circular(0),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child:  IntrinsicWidth(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ( message['attachment'] == '' ) ? Container() : GestureDetector(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/app_icon.png',
                              width: 20,
                              height: 20,
                              repeat: ImageRepeat.noRepeat,
                              alignment: Alignment.center,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6,),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text( LanguageNotifier.of(context)!.translate('photo'), style: const TextStyle( color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold) ),
                                ( message['text'] != '' ) ? Container( constraints: BoxConstraints(maxWidth: currentScreenWidth - 100), child: Text(message['text'], style: const TextStyle( color: Colors.white, fontSize: 16.0))) : Container(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _previewImage(context, message['attachment'] ),
                    ),
                    ( message['attachment'] == '' ) ?
                      ( isTimeInSameRow ) ? Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text( message['text'], style: const TextStyle( color: Colors.white, fontSize: 16.0), textAlign: TextAlign.left, ),
                          const SizedBox(width: 10,),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(formattedDate, style: const TextStyle( color: Colors.white70, fontSize: 11.0), textAlign: TextAlign.right,),
                          )
                        ],
                      ) : Text( message['text'], style: const TextStyle( color: Colors.white, fontSize: 16.0), textAlign: TextAlign.left, ) : Container(),
                    const SizedBox( height: 2,),
                    ( message['text'].toString().length > 20 || message['attachment'] != '' ) ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        //( (message['readBy'] as List).isNotEmpty ) ? Icon(Icons.done_all, size: 16, color: Colors.white,) : Icon(Icons.check, size: 16, color: Colors.white,),
                        Text(formattedDate, style: const TextStyle( color: Colors.white70, fontSize: 11.0), textAlign: TextAlign.right,),
                      ],
                    ) : Container(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      onLongPress: (){
        try{
          Clipboard.setData(ClipboardData(text: message['text']));
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(LanguageNotifier.of(context)!.translate('copied')),)
          );
        }catch( e ){
          debugPrint( e.toString() );
        }
      },
    );
  }

  Widget _receiver( dynamic message, int index, bool isNextSame ){
    if( message['attachment'] != '' ){
      loadImagesInBG( message['attachment'] );
    }

    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    dynamic avatar = otherUser['avatar'];

    String formattedDate = UtilityService().getTextSentDateTime( message['timestamp'] );

    bool isTimeInSameRow = ( message['text'].toString().length < 20 ) ? true : false;
    double currentScreenWidth = MediaQuery.of(context).size.width*0.8;

    String avatarUrl = (avatar['type'] == 'avatar') ? avatar['url'] : UserManager().getServerUrl('/').toString()+avatar['url'];

    return GestureDetector(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ( !isNextSame ) ? CircleAvatar(
              backgroundColor: background,
              radius: 16.0,
              child: UserAvatar(url: avatarUrl, type: avatar['type'], radius: 13.0),
            ) : const SizedBox(width: 30,),
            const SizedBox(width: 5,),
            Container(
              constraints: BoxConstraints(
                maxWidth: currentScreenWidth - 50
              ),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFAFAFA)),
                color:  const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(15),
                  topLeft: (isNextSame) ? Radius.circular(15) : Radius.circular(0),
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              padding: const EdgeInsets.all(8.0),
              child:  IntrinsicWidth(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ( message['attachment'] == '' ) ? Container() : GestureDetector(
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/app_icon.png',
                            width: 20,
                            height: 20,
                            repeat: ImageRepeat.noRepeat,
                            alignment: Alignment.center,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 6,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text( '${LanguageNotifier.of(context)!.translate('photo')}  ', style: TextStyle( color:  myColors.borderColor!, fontWeight: FontWeight.bold ) ),
                              ( message['text'] != '' ) ? Container( constraints: BoxConstraints(maxWidth: currentScreenWidth - 100), child: Text(message['text'], style: TextStyle( color: myColors.borderColor!, fontSize: 16.0))) : Container(),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _previewImage(context, message['attachment'] ),
                    ),
                    ( message['attachment'] == '' ) ? ( isTimeInSameRow ) ? Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text( message['text'], style: TextStyle( color: myColors.borderColor!, fontSize: 16.0), textAlign: TextAlign.left, ),
                        const SizedBox(width: 10,),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(formattedDate, style: TextStyle( color: myColors.borderColor!, fontSize: 11.0), textAlign: TextAlign.right,),
                        )
                      ],
                    ) : Text( message['text'], style: TextStyle( color: myColors.borderColor!, fontSize: 16.0), ) : Container(),
                    const SizedBox( height: 2,),
                    ( !isTimeInSameRow || message['attachment'] != '' ) ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        //( (message['readBy'] as List).isNotEmpty ) ? Icon(Icons.done_all, size: 16, color: Colors.white,) : Icon(Icons.check, size: 16, color: Colors.white,),
                        Text(formattedDate, style: TextStyle( color: myColors.borderColor!, fontSize: 11.0), textAlign: TextAlign.right,),
                      ],
                    ) : Container(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      onLongPress: (){
        setState(() {
          showSentTimeIndex = index;
        });
        Future.delayed( const Duration(seconds: 5), () {
          if( showSentTimeIndex == index ){
            setState(() {
              showSentTimeIndex = -1;
            });
          }
        });
        //_showMenu(context);
        Clipboard.setData(ClipboardData(text: message['text']));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard'),)
        );
      },
    );
  }

  Widget _buildInputField( BuildContext context ) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    return TextFormField(
      textCapitalization: TextCapitalization.sentences,
      controller: _textController,
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: LanguageNotifier.of(context)!.translate('msg_placeholder'),
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide( style: BorderStyle.solid, color: myColors.borderColor!  ),
          borderRadius: BorderRadius.circular(100)
        ),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide( style: BorderStyle.solid, color: myColors.borderColor!  ),
            borderRadius: BorderRadius.circular(100)
        ),
        suffixIcon : SizedBox(
          width: 100,
          child: Row(
              children: [
                GestureDetector(
                  onHorizontalDragUpdate: (details) => showCameraDialog( context ),
                  onLongPress: () => showCameraDialog( context ),
                  child: IconButton(
                    icon: const Icon( Icons.camera_alt ),
                    onPressed: (){
                      showCameraDialog( context );
                    },
                  ),
                ),
                ( isSendingMessage ) ?
                  SizedBox(
                    width: 22.0,
                    height: 22.0,
                    child: CircularProgressIndicator( color: myColors.brandColor!, strokeWidth: 2,),
                  ) :
                  IconButton( icon: const Icon(Icons.send),
                    onPressed: (){
                      _sendMessage( _textController.text, '' );
                    }
                  ),
              ],
          ),
        )
      ),
    );
  }

  void _sendMessage(String text, String url) async {
    // send message logic
    if (text.isNotEmpty || url.isNotEmpty ) {
      // Clear Input Field
      _textController.clear();
      _captionController.clear();

      setState(() { isSendingMessage = true; });
      var data = {
        "chatId" : conversation['_id'],
        "msg" : {
          "sender" : currentUser['uid'],
          "text" : text.trim(),
          "attachment" : url,
          "readBy" : [],
          "timestamp" : DateTime.now().toIso8601String()
        }
      };
      if( ss.socket.connected ){
        ss.socket.emitWithAck('send-message', data, ack: ( response ){
          if( response['status'] ){
            setState(() {
              (conversation['messages'] as List).add(response['message']);
            });
            Future.delayed(const Duration(microseconds: 10000), () {
              _scrollDown();
            });
          }else{
            debugPrint( response['error'] );
            return;
          }
        });
      }else{
        return;
      }
      if( otherUser['tokens']['fcm'] != null && otherUser['tokens']['fcm'] != '' ){

        // Get Server Url
        final protocol  = dotenv.env['SERVER_PROTOCOL'];
        final server_url = dotenv.env['SERVER_URL'];
        Uri serverUrl;
        if( protocol == 'http' ){
          serverUrl = Uri.http( '$server_url' , 'send-notification');
        }else{
          serverUrl = Uri.https( '$server_url' , 'send-notification');
        }
        if(url != '' ) {
          text = LanguageNotifier.of(context)!.translate('image_attachment');
        }

        // Send Notification
        final response = await http.post(serverUrl, body: {
          'title'  : currentUser['username'],
          'message' : text,
          'token' : otherUser['tokens']['fcm'],
        });
        if( response.statusCode == 200 ){
          debugPrint( response.body );
        }else{
          debugPrint( response.body );
        }
      }
      setState(() { isSendingMessage = false; });
    }
  }

  /// UPLOAD IMAGE TO SERVER
  void uploadAttachment() async {
    setState(() { isSendingMessage = true; });
    // COMPRESS IMAGE
    File? compressedImageFile = await UtilityService().compressAndConvertToFile(_image!);
    if( compressedImageFile != null ){
      _image = compressedImageFile;
    }
    final response = await ChatService().uploadImage( _image! );
    if( response['status'] && response['file'] != '' && mounted ){
      final url = UserManager().getServerUrl('/').toString()+response['file'];
      _sendMessage( _captionController.text, url);
    }
    setState(() { isSendingMessage = false; });
  }

  void _showPreviewDialog(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    _captionController.clear();
    showGeneralDialog(
        context: context,
        barrierColor: Colors.black12.withOpacity(1),
        pageBuilder: (_, animation1, ___) {
          return StatefulBuilder(
            builder: (context, setState ) {
              return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Scaffold(
                    backgroundColor: Colors.black12.withOpacity(1),
                    body: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            _image!,
                            fit: BoxFit.fitHeight,
                            height: double.infinity,
                            width: double.infinity,
                            alignment: Alignment.center,
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
                            title: Text(
                              otherUser['username']+' | '+(distance/1000).toStringAsFixed(1)+' '+LanguageNotifier.of(context)!.translate('km'),
                              style: const TextStyle(color: Colors.white),
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
                                  style: const TextStyle(
                                      color: Colors.white
                                  ),
                                  cursorColor: Colors.white,
                                  controller: _captionController,
                                  decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.5),
                                      hintText: LanguageNotifier.of(context)!.translate('caption'),
                                      hintStyle: const TextStyle(color: Colors.white),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                                      border: OutlineInputBorder(
                                          borderSide: const BorderSide( style: BorderStyle.solid, color: Color(0xFFFFFFFF)   ),
                                          borderRadius: BorderRadius.circular(100)
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide( style: BorderStyle.solid, color: Colors.transparent ),
                                          borderRadius: BorderRadius.circular(100)
                                      ),
                                      suffixIcon : ( !isSendingMessage ) ?
                                      IconButton(
                                          icon: const Icon(Icons.send, color: Color(0xFFFFFFFF),),
                                          onPressed: () async {
                                            try{
                                              uploadAttachment();
                                              Navigator.pop(context);
                                            }catch( e ){
                                              setState(() { isSendingMessage = false; });
                                              debugPrint( e.toString() );
                                            }
                                          }
                                      ) :
                                      SizedBox(
                                        width: 25,
                                        height: 25,
                                        child: Transform.scale(
                                          scale: 0.5,
                                          child: CircularProgressIndicator(color: myColors.brandColor!),
                                        ),
                                      )
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
              );
            }
          );
        },
    );
  }

  void showCameraDialog( BuildContext context ){
    showGeneralDialog(
        context: context,
        barrierColor: Colors.black12.withOpacity(1),
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
                builder: (context, setState ) {
                  return Consumer<PermissionManager>(
                      builder: (context, permissionManager, child) {
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
                                  onSelectFile : ( XFile file ){
                                    File image = File(file.path);
                                    setState( () {
                                      _image = image;
                                    });
                                    Navigator.pop(context);
                                    _showPreviewDialog( context );
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
                                  centerTitle: true,
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: background,
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
                              ( !permissionManager.isLocationPermissionGranted ) ?  Positioned(
                                  child: UtilityService().showAlertDialog('', context, setState)
                              ) :
                              ( !permissionManager.isLocationServiceEnabled ) ?  Positioned(
                                  child: UtilityService().showAlertDialog('', context, setState)
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
        },
        transitionBuilder: (_, animation1, __, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
          ).animate(animation1),
          child: child,
        );
      },
    );
  }

  void _previewImage(BuildContext context, String url ) {
    _captionController.clear();
    showGeneralDialog(
        context: context,
        barrierColor: Colors.black12.withOpacity(1),
        pageBuilder: (_, __, ___) {
          return GestureDetector(
            onVerticalDragUpdate: (details) {
              int sensitivity = 10;
              if (details.delta.dy > sensitivity ||
                  details.delta.dy < -sensitivity) {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
              backgroundColor: Colors.black12.withOpacity(1),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      //padding: const EdgeInsets.only(top: 25),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.fitHeight,
                        height: double.infinity,
                        width: double.infinity,
                        alignment: Alignment.center,
                        progressIndicatorBuilder: (context, url, downloadProgress){
                          return Center(child: CircularProgressIndicator( value: downloadProgress.progress ));
                        },
                        // errorWidget: (context, url, error) => CircleAvatar(
                        //   radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
                        //   backgroundColor: Colors.white,
                        //   backgroundImage: const AssetImage('assets/app_icon.png'),
                        //   //child: CircularProgressIndicator(),
                        // ),
                      ),
                      // child: Image.network(
                      //   url,
                      //   scale: 1.0,
                      //   fit: BoxFit.fitHeight,
                      //   height: double.infinity,
                      //   width: double.infinity,
                      //   alignment: Alignment.center,
                      //   loadingBuilder: (BuildContext context, Widget child,
                      //       ImageChunkEvent? loadingProgress) {
                      //     if (loadingProgress == null) return child;
                      //     return Center(
                      //       child: CircularProgressIndicator(
                      //         value: loadingProgress.expectedTotalBytes != null
                      //             ? loadingProgress.cumulativeBytesLoaded /
                      //             loadingProgress.expectedTotalBytes!
                      //             : null,
                      //       ),
                      //     );
                      //   },
                      // ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      leading: Container(),
                      actions: [
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  void _markChatAsRead()  async{
    if( conversation != null && ss.socket.connected ){
      ss.socket.emit('mark-as-read', {
        'chatId' : conversation['_id'],
        'uid' : currentUser['uid']
      });
    }
  }

  // GET USER STORY
  // This function gets user story from local loaded data for that user
  void getUserStories( dynamic user, dynamic conversation ) {
    // GET AVATAR URL
    dynamic url = user['avatar']['url'].toString();
    // GET AVATAR TYPE
    dynamic type = user['avatar']['type'].toString();
    // CHECK IF STORY EXIST
    if (user['stories'].length > 0) {
      // SHOW STORIES
      _viewStories(user['stories'], user['username'], user['_id'], type, url, conversation: conversation );
    }
  }

  // VIEW USER STORY
  // This function displays usr stories
  void _viewStories( List<dynamic> stories, dynamic username, dynamic uid, dynamic avatarType, dynamic avatarUrl, { dynamic conversation = '' }) {
    // SET user is not holding the story (Pausing)
    setState(() => isHoldingStoryDialog = false);
    // Show Dialog
    showGeneralDialog(
        context: context,
        barrierColor: Colors.transparent,
        pageBuilder: (_, animation1, ___) {
          return StatefulBuilder(builder: (context, setState) {
            return Dismissible(
                direction: DismissDirection.vertical,
                onDismissed: (_) {
                  Navigator.of(context).pop();
                },
                onUpdate: (DismissUpdateDetails details) {
                  if (details.progress <= 0) {
                    // SET User is not holding story
                    setState(() => isHoldingStoryDialog = false);
                  }
                  if (details.progress > 0 && isHoldingStoryDialog == false) {
                    // SET User is holding story
                    setState(() => isHoldingStoryDialog = true);
                  }
                },
                key: const Key("key"),
                // PREVIEW STORY WIDGET
                child: PreviewStories(
                    // IS IT CURRENT USER STORY OR OTHER
                    whoIm: 'other',
                    // HOLDING STATUS
                    onHold: isHoldingStoryDialog,
                    // STORY LIST <ARRAY>
                    storiesList: stories,
                    // USERNAME
                    username: username,
                    // USER AVATAR TYPE (NETWORK, ASSET)
                    avatarType: avatarType,
                    // USER AVATAR URL
                    avatarUrl: avatarUrl,
                    // ACTION
                    onAction: (dynamic value) async {
                      if (value == null) {
                        // CLOSE STORY DIALOG
                        Navigator.of(context).pop();
                      }
                    },
                    onReportAction: (dynamic data) async {
                      // CLOSE STORY DIALOG
                      Navigator.of(context).pop();
                      // IF ACTION IS VANISH-USER
                      if( data['action'] == 'vanish_user' ){
                        // VANISH USER
                        vanishUser( conversation );
                      }
                      // IF ACTION IS REPORT-USER
                      else if( data['action'] == 'report_user' ){
                        // REPORT USER USING SOCKET
                        ss.socket.emitWithAck( 'report-user', { "reported_by" : currentUser['uid'] ,"reported_to" : uid, "reason" : data['reason'] },  ack: (response) {
                          // CHECK RESPONSE
                          if(response['status']){}
                        });
                      }
                      // IF ACTION IS REPORT-STORY
                      else if( data['action'] == 'report_story' ){
                        // REPORT USER STORY
                        ss.socket.emitWithAck( 'report-story', { "reported_by" : currentUser['uid'] ,"reported_to" : uid, "reason" : data['reason'], 'storyId' : data['storyId']},  ack: (response) {
                          // CHECK RESPONSE
                          if(response['status']){}
                        });
                      }
                    }
                ));
          });
        });
  }

  // VANISH USER
  // This function vanish user
  void vanishUser(dynamic chat) {
    // Delete Chat
    ss.socket.emitWithAck('remove-chat', {'chatId': chat['_id']}, ack: (chatResponse) async {
          // CHECK SUCCESS RESPONSE
          if (chatResponse['status']) {
            // GET USER ID
            final String userId = otherUser['_id'];
            // SET CHAT TO EMPTY
            conversation = null;
            // BLOCK USER
            ss.socket.emitWithAck('block-user', {'self': currentUser['uid'], 'other': userId}, ack: (response) async {
                  // CHECK SUCCESS RESPONSE
                  if (response['status'] == true) {
                    // SET BLOCK STATUS TO TRUE
                    isBlocked = true;
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['message']),
                      ),
                    );
                  }
                });
            setState(() {});
          }
        });
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if( conversation != null ){
      _markChatAsRead();
    }
    _textController.dispose();
    _focusNode.dispose();
    conversation = null;
    timer?.cancel();
    readTimer?.cancel();
    // Unsubscribed to socket listeners
    // ss.socket.off('new-message');
    // ss.socket.off('seen-msg');
    // ss.socket.off('chat-deleted');
    // ss.socket.off('blocked');
    debugPrint('Disposing Chat & events');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    String avatarUrl = '';
    if( otherUser != null ){
      avatarUrl = (otherUser['avatar']['type'] == 'avatar') ? otherUser['avatar']['url'] : UserManager().getServerUrl('/').toString()+otherUser['avatar']['url'];
    }

    return Consumer2<PermissionManager, LocationManager>(
        builder: (context, permissionManager, locationManager, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(
                    child: Scaffold(
                      backgroundColor: myColors.appSecBgColor,
                      appBar: AppBar(
                        //leadingWidth: MediaQuery.of(context).size.width*0.5,
                        leading: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios),
                        ),
                        title: (otherUser != null) ? Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => getUserStories( otherUser, conversation ),
                              child: CircleAvatar(
                                backgroundColor: background,
                                radius: 20.0,
                                child: UserAvatar(url: avatarUrl, type: otherUser['avatar']['type'], radius: 17.0),
                              ),
                            ),
                            const SizedBox(width: 10.0,),
                            Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.contain,
                                      child: Row(
                                        children: [
                                          Text(
                                              otherUser['username']+' | ',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 16)
                                          ),
                                          Text('${(distance/1000).toStringAsFixed(1)} ${LanguageNotifier.of(context)!.translate('km')}', style: const TextStyle(fontSize: 14),)
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                            ),
                          ],
                        ) : const Text('Loading'),
                        actions: [
                          PopupMenuButton<String>(
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10.0))
                            ),
                            padding: EdgeInsets.zero,
                            itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem(
                                padding: const EdgeInsets.only(left: 10, right: 5),
                                height: 0,
                                value: 'block',
                                child: Row(children: <Widget>[
                                  Icon(
                                    Icons.block,
                                    color: myColors.appSecTextColor!,
                                  ),
                                  const SizedBox(
                                    width: 15.0,
                                  ),
                                  Text(LanguageNotifier.of(context)!
                                      .translate('vanish')),
                                ]),
                                onTap: () async {
                                  /// REMOVE CHAT
                                  ss.socket.emitWithAck('remove-chat', { 'chatId' : conversation['_id'] }, ack : ( response ) async {
                                    if( response['status'] ){
                                      /// BLOCK USER
                                      ss.socket.emitWithAck('block-user', { 'self' : currentUser['uid'], 'other' : otherUser['_id']}, ack: ( response  ) async {
                                        if( response['status'] == true ){
                                          // ScaffoldMessenger.of(context).showSnackBar(
                                          //   SnackBar( content: Text(LanguageNotifier.of(context)!.translate('success_block')), ),
                                          // );
                                          Navigator.popAndPushNamed(context, '/messages');
                                        }else{
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar( content: Text( response['message'] ), ),
                                          );
                                        }
                                      });
                                    }else{
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar( content: Text( response['error'] ), ),
                                      );
                                    }
                                  });
                                  final response = await userManager.toggleBlock(
                                      currentUser['uid'],
                                      otherUser['_id'],
                                      status: true
                                  );
                                  if( response['status'] && mounted ){
                                    // ScaffoldMessenger.of(context).showSnackBar(
                                    //   SnackBar(
                                    //     content: Text(LanguageNotifier.of(context)!.translate('success_block')),
                                    //   ),
                                    // );
                                    Navigator.popAndPushNamed(context, '/messages');
                                  }else{
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text( response['msg'] ),
                                      ),
                                    );
                                  }

                                },
                              ),
                            ],
                          )
                          ,
                        ],
                      ),
                      body:
                      ( !ss.socket.connected ) ? Center( child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.signal_wifi_connected_no_internet_4_outlined, size: 56,),
                          const SizedBox(height: 10,),
                          Text( LanguageNotifier.of(context)!.translate('offline_text'), style: const TextStyle(fontSize: 18), ),
                          const SizedBox(height: 5,),
                          Text( LanguageNotifier.of(context)!.translate('offline_hint'), style: const TextStyle(fontSize: 14,),textAlign: TextAlign.center, ),
                          const SizedBox(height: 10,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox( width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,),),
                              const SizedBox(width: 10,),
                              Text(LanguageNotifier.of(context)!.translate('reconnecting'))
                            ],
                          )
                        ], ),) :
                      ( isBlocked ) ? const Center( child: Text( 'BLOCKED' ),) :
                      (conversation != null ) ?
                      Column(
                        children: [
                          Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                                child: _buildChat(),
                              )
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            child: _buildInputField( context ),
                          )
                        ],
                      ) :
                      Center( child: CircularProgressIndicator( color: myColors.brandColor! ),),
                    )
                ),
                ( (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? Positioned(
                    child: UtilityService().showLocationAlertDialog(
                        context,
                        currentUser,
                        _scrollDown,
                        type: 'permission'
                    )
                ) :
                (!locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied) ? Positioned(
                    child: UtilityService().showLocationAlertDialog(context, currentUser, _scrollDown)
                ) : Container(),
                Container(),
              ],
            ),
          );
        }
    );
  }
}