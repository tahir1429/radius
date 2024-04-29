import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/pages/chat.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/services/chatService.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/locationManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:badges/badges.dart' as badges;
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:radius_app/widgets/userAvatar.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:radius_app/widgets/previewStories.dart';
import 'package:video_player/video_player.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/widgets/camera.dart';

class Messages extends StatefulWidget with ChangeNotifier {
  Messages({Key? key}) : super(key: key);

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages> with WidgetsBindingObserver {
  UtilityService utilityService = UtilityService();
  UserManager userManager = UserManager();
  ChatService chatService = ChatService();
  bool isSpinning = false;
  List conversations = [];
  List<dynamic> users = [];
  double radiusInMeters = 100.0;
  final SocketSingleton ss = SocketSingleton();
  VideoPlayerController? _videoController;
  bool isSavingStory = false;
  dynamic currentUser;

  Timer? timer;
  int totalUnreadCounter = 0;
  int homeTab = 0;

  bool isHoldingStoryDialog = false;
  final TextEditingController _storyCaptionController = TextEditingController();
  String selectedMediaType = '';

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    /// TODO: implement initState
    super.initState();

    /// Load all chats
    loadChats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _storyCaptionController.dispose();
    if (timer != null) {
      timer!.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        //loadChats();
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

  void loadChats() async {
    homeTab = await StorageManager.readData('home-tab') ?? 0;
    radiusInMeters = await StorageManager.readData('radius');
    currentUser = await StorageManager.getUser();

    setState(() {
      isSpinning = true;
    });

    if (currentUser != null) {
      /// UPDATE STATUS IF NOT ONLINE
      userManager.updateUserAvailability(currentUser['uid'], true);
      /// IF SOCKET CONNECTED
      if (ss.socket.connected) {
        /// GET ALL CHATS
        ss.socket.emitWithAck(
            'get-all-chats', {'self': currentUser['uid'], "withoutCount": true},
            ack: (response) async {
          if (response['status']) {
            users = response['users'];
            List temp = response['chats'];
            final data = temp.map((item) async {
              String otherUid = '';
              for (var i = 0; i < item['members'].length; i++) {
                if (item['members'][i] != currentUser['uid']) {
                  otherUid = item['members'][i];
                  break;
                }
                continue;
              }
              final response = await UserManager().getUserBy(id: otherUid);
              final user = response['user'];
              final currentUserCoordinates = currentUser['location']['coordinates'];
              final otherUserCoordinates = user['location']['coordinates'];
              item['otherMemberInfo'] = user;
              item['distance'] = utilityService.calculateDistanceInMeters(
                currentUserCoordinates[1],
                currentUserCoordinates[0],
                otherUserCoordinates[1],
                otherUserCoordinates[0],
              );
              if ((item['distance'] / radiusInMeters) < 0.33) {
                item['background'] = Colors.green;
              } else if ((item['distance'] / radiusInMeters) < 0.66) {
                item['background'] = Colors.yellow;
              } else if ((item['distance'] / radiusInMeters) < 1) {
                item['background'] = Colors.red;
              } else {
                item['background'] = Colors.red;
              }
              List blockList = user['blockedBy'] ?? [];
              final double userRadius =
                  double.parse(item['distance'].toString());

              bool show = false;

              // IF USER IS IN RADIUS
              if (userRadius <= radiusInMeters) {
                final List messages = item['messages'] ?? [];
                if (!blockList.contains(currentUser['uid']) &&
                    messages.isNotEmpty) {
                  show = true;
                }
              }
              // IF USER IS NOT IN RADIUS
              else if (radiusInMeters < userRadius) {
                // DELETE CONVERSATION
                if (ss.socket.connected) {
                  ss.socket.emitWithAck('remove-chat', {'chatId': item['_id']},
                      ack: (output) {
                    debugPrint('Chat deleted due to out of radius');
                    debugPrint(output.toString());
                  });
                }
                //chatService.deleteChat( data['documentId'] );
              }

              if (show) {
                return item;
              } else {
                return null;
              }
            }).toList();
            final output = await Future.wait(data);
            output.removeWhere((e) => e == null);
            if (mounted) {
              setState(() {
                conversations = output;
                isSpinning = false;
              });
            }
          } else {
            setState(() {
              isSpinning = false;
            });
          }
        });

        ss.socket.onDisconnect((data) => {if (mounted) setState(() => {})});

        /// EVENT: ON SOCKET RE-CONNECTED
        /// reload the chats to get latest updates
        /// ss.socket.onConnect((data) => {if (mounted) setState(() => {})});
        // ss.socket.onReconnect((data) {
        //   if (mounted) loadChats();
        // });
      } else {
        SocketSingleton().init( currentUser['uid'] );
        setState(() {
          isSpinning = false;
        });
      }

      /// EVENT: ON NEW MESSAGE
      /// Push new message to the specific chat in local conversations
      SocketSingleton().listenToEvent('new-message',  (data){
        if (mounted && conversations.isNotEmpty) {
          for (var index = 0; index < conversations.length; index++) {
            if (conversations[index]['_id'] == data['chatId']) {
              (conversations[index]['messages'] as List)
                  .add(data['message']);
              conversations[index]['updatedAt'] =
                  DateTime.now().toIso8601String();
              _refreshConversation();
            }
          }
        }
      });

      /// EVENT: ON CHAT DELETED
      /// Delete the deleted chat from local conversations
      SocketSingleton().listenToEvent('chat-deleted', (data){
        for (var index = 0; index < conversations.length; index++) {
          if (mounted && conversations[index]['_id'] == data['chatId']) {
            conversations.removeAt(index);
            // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            //   content: Text(
            //       LanguageNotifier.of(context)!.translate('chat_removed')),
            // ));
            _refreshConversation();
          }
        }
      });

      /// EVENT: ON CHAT CREATED
      /// Push new chat to the local conversations
      SocketSingleton().listenToEvent('chat-created', (data) async {
        final chat = data['chat'];
        String otherUid = '';
        for (var i = 0; i < chat['members'].length; i++) {
          if (chat['members'][i] != currentUser['uid']) {
            otherUid = chat['members'][i];
            break;
          }
          continue;
        }
        final response = await UserManager().getUserBy(id: otherUid);
        if (!response['status']) return;

        final user = response['user'];
        final currentUserCoordinates = currentUser['location']['coordinates'];
        final otherUserCoordinates = user['location']['coordinates'];
        chat['otherMemberInfo'] = user;
        chat['distance'] = utilityService.calculateDistanceInMeters(
          currentUserCoordinates[1],
          currentUserCoordinates[0],
          otherUserCoordinates[1],
          otherUserCoordinates[0],
        );

        if ((chat['distance'] / radiusInMeters) < 0.33) {
          chat['background'] = Colors.green;
        } else if ((chat['distance'] / radiusInMeters) < 0.66) {
          chat['background'] = Colors.yellow;
        } else if ((chat['distance'] / radiusInMeters) < 1) {
          chat['background'] = Colors.red;
        } else {
          chat['background'] = Colors.red;
        }
        if (mounted) {
          bool isExist = false;
          dynamic foundAt = -1;
          conversations.map((item) {
            if (item['_id'] == chat['_id']) {
              isExist = true;
              foundAt = conversations.indexOf(item);
            }
            return item;
          });
          if (isExist && foundAt != -1) {
            conversations[foundAt] = chat;
          } else {
            conversations.add(chat);
          }
          _refreshConversation();
        }
      });

      /// EVENT: ON SOCKET RECONNECTED/DISCONNECTED
      /// Re-build the activity
      SocketSingleton().listenToEvent('connect', (data) {
        print('CONNECTED');
        loadChats();
      });
      SocketSingleton().listenToEvent('reconnect', (data) {
        print('RECONNECTED');
        loadChats();
      });
      SocketSingleton().listenToEvent('disconnect', (data) {
        print('DISCONNECTED');
        setState(() => {});
      });
      //SocketSingleton().listenToEvent('blocked', (data) => loadChats() );
    } else {
      setState(() {
        isSpinning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired'),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const SignIn()),
                (Route<dynamic> route) => false);
      }
    }
  }

  String getLastMessage(List messages) {
    String msg = 'No Message';
    if (messages.isNotEmpty) {
      var message = messages[messages.length - 1];
      if (message['attachment'] != '') {
        msg = LanguageNotifier.of(context)!.translate('image_attachment');
      } else {
        msg = message['text'];
      }
    }
    return msg.replaceAll("\n", " ");
  }

  String timeSince(List messages) {
    String since = '';
    if (messages.isEmpty) {
      return since;
    }
    DateTime dt = DateTime.parse(messages[messages.length - 1]['timestamp']);
    DateTime now = DateTime.now();
    Duration difference = now.difference(dt);

    int days = difference.inDays;
    int hours = (difference.inHours > 0) ? difference.inHours % 24 : 0;
    int minutes = difference.inMinutes % 60;
    int seconds = difference.inSeconds % 60;

    if (days >= 365) {
      since = '${days ~/ 365}y';
    } else if (days >= 30) {
      since = '${days ~/ 30}m';
    } else if (days >= 7) {
      since = '${days ~/ 7}w';
    } else if (days > 0) {
      since = '${days}d';
    } else if (hours > 0) {
      since = '${hours}h';
    } else if (minutes > 0) {
      since = '${minutes}m';
    } else {
      since = '${seconds}s';
    }
    return since;
  }

  void showReportDialog(BuildContext context, dynamic conversation) {
    TextEditingController controller = TextEditingController();
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    final RenderObject overlay =
        Overlay.of(context).context.findRenderObject()!;
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text(LanguageNotifier.of(context)!.translate('report')),
              content: SizedBox(
                width: overlay.paintBounds.size.width * 0.9,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: LanguageNotifier.of(context)!
                          .translate('msg_placeholder')),
                ),
              ),
              actions: <Widget>[
                TextButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: Text(
                      LanguageNotifier.of(context)!.translate('cancel'),
                      style: TextStyle(color: myColors.appSecTextColor!),
                    )),
                FilledButton(
                  onPressed: () async {
                    var data = {
                      "reported_by": {
                        "uid": currentUser['uid'],
                        "username": currentUser['username'],
                        "email": currentUser['email'],
                      },
                      "reported_to": {
                        "uid": conversation['otherMemberInfo']['uid'],
                        "username": conversation['otherMemberInfo']['username'],
                        "email": conversation['otherMemberInfo']['email'],
                      },
                      "message": controller.text
                    };
                    final response = await chatService.reportChat(data);
                    if (response['status'] && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LanguageNotifier.of(context)!
                              .translate('success_report')),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(response['msg']),
                        ),
                      );
                    }
                    if (mounted) {
                      setState(() {});
                      Navigator.pop(context);
                    }
                  },
                  child:
                      Text(LanguageNotifier.of(context)!.translate('report')),
                ),
              ]);
        });
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  /// VANISH USER
  /// This function first delete the user chat then block this user
  void vanishUser(dynamic conversation) {
    // Delete Chat
    ss.socket.emitWithAck('remove-chat', {'chatId': conversation['_id']},
        ack: (chatResponse) async {
      if (chatResponse['status']) {
        final String userId = conversation['otherMemberInfo']['_id'];
        // BLOCK USER
        ss.socket.emitWithAck(
            'block-user', {'self': currentUser['uid'], 'other': userId},
            ack: (response) async {
          if (response['status'] == true) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(
            //         LanguageNotifier.of(context)!.translate('success_block')),
            //   ),
            // );
            conversations
                .removeWhere((item) => item['_id'] == chatResponse['chatId']);
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
      } else {
        showToast(chatResponse['error']);
      }
    });
  }

  void getUserStories( dynamic user, dynamic conversation ) {
    dynamic url = user['avatar']['url'].toString();
    dynamic type = user['avatar']['type'].toString();
    if (user['stories'].length > 0) {
      _viewStories(user['stories'], user['username'], user['_id'], type, url, conversation: conversation );
    }
  }

  bool userHasStories( List stories ) {
    return (stories.isNotEmpty) ? true : false;
  }

  void _viewStories( List<dynamic> stories, dynamic username, dynamic uid, dynamic avatarType, dynamic avatarUrl, { dynamic conversation = '' }) {
    setState(() => isHoldingStoryDialog = false);
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
                    setState(() => isHoldingStoryDialog = false);
                  }
                  if (details.progress > 0 && isHoldingStoryDialog == false) {
                    setState(() => isHoldingStoryDialog = true);
                  }
                },
                key: const Key("key"),
                child: PreviewStories(
                  whoIm: 'other',
                  onHold: isHoldingStoryDialog,
                  storiesList: stories,
                  username: username,
                  avatarType: avatarType,
                  avatarUrl: avatarUrl,
                  onAction: (dynamic value) async {
                    if (value == null) {
                      Navigator.of(context).pop();
                    }
                  },
                  onReportAction: (dynamic data) async {
                    Navigator.of(context).pop();
                    if( data['action'] == 'vanish_user' ){
                      vanishUser( conversation );
                    }
                    else if( data['action'] == 'report_user' ){
                      ss.socket.emitWithAck( 'report-user', { "reported_by" : currentUser['uid'] ,"reported_to" : uid, "reason" : data['reason'] },  ack: (response) {
                        if(response['status']){

                        }
                      });
                    }
                    else if( data['action'] == 'report_story' ){
                      ss.socket.emitWithAck( 'report-story', { "reported_by" : currentUser['uid'] ,"reported_to" : uid, "reason" : data['reason'], 'storyId' : data['storyId']},  ack: (response) {
                        if(response['status']){

                        }
                      });
                    }
                  }
                ));
          });
        });
  }

  void _openChatPage(dynamic uid) {
    if (timer != null) {
      timer!.cancel();
    }
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (context) =>
              Chat(currentUser: currentUser, receiverUserId: uid)),
    )
        .then((value) {
      loadChats();
    });
  }

  void showCameraDialog(
      BuildContext context, Future<void> Function(dynamic image) callback,
      {bool showGallery = false}) {
    showGeneralDialog(
        context: context,
        barrierColor: Colors.black12.withOpacity(1),
        pageBuilder: (_, __, ___) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(builder: (context, setState) {
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
                              onSelectFile: (XFile file) {},
                              onSelect: ( XFile file, String type ){
                                selectedMediaType = type;
                                File image = File(file.path);
                                Navigator.pop(context);
                                callback(image);
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
                                  icon: const Icon(Icons.close)),
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
                                  const SizedBox(
                                    width: 10.0,
                                  ),
                                  Expanded(
                                      child: Text(currentUser['username'],
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white))),
                                ],
                              ),
                            ),
                          ),
                          ( (!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? Positioned(
                              child: UtilityService().showLocationAlertDialog(
                                  context,
                                  currentUser,
                                  _refreshConversation,
                                  type: 'permission'
                              )
                          ) :
                          ( !locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? UtilityService().showLocationAlertDialog(
                              context,
                              currentUser,
                              _refreshConversation
                          ) : Container(),
                        ],
                      ),
                    );
                  }
              );
            }),
          );
        });
  }

  Future<void> _previewNewStoryDialog(dynamic image) async {
    List<String> videoExtensions = [
      '.mov',
      '.mp4',
      '.webm',
      '.ogg',
      '.avi',
      '.flv',
      '.mpg',
      '.mpeg'
    ];
    List<String> imageExtensions = [
      '.jpg',
      '.jpeg',
      '.gif',
      '.png',
      '.raw',
      '.bmp',
      '.tif',
      '.tiff'
    ];
    bool isVideo = false;
    FocusNode focusNode = FocusNode();

    if (image != null) {
      String ext = path.extension((image as File).path);

      if (videoExtensions.contains(ext.toLowerCase())) {
        isVideo = true;
      }
    }

    _storyCaptionController.clear();
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black12.withOpacity(1),
      pageBuilder: (_, animation1, ___) {
        return StatefulBuilder(builder: (context, setState) {
          if (isVideo && _videoController == null) {
            _videoController = VideoPlayerController.file(image,
                videoPlayerOptions: VideoPlayerOptions())
              ..initialize().then((_) {
                // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
                setState(() {});
              })
              ..addListener(() {
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
                      (image != null)
                          ? Positioned.fill(
                              child: (!isVideo)
                                  ? (selectedMediaType == 'camera') ?
                                    Image.file(image, fit: BoxFit.fitHeight, height: double.infinity, width: double.infinity, alignment: Alignment.center ) :
                                    Image.file(image, fit: BoxFit.contain)
                                  : (_videoController != null &&
                                          _videoController!.value.isInitialized)
                                      ? AspectRatio(
                                          aspectRatio: _videoController!
                                              .value.aspectRatio,
                                          child: VideoPlayer(_videoController!))
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                            )
                          : Container(),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AppBar(
                          backgroundColor: Colors.transparent,
                          leading: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close)),
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
                                style: const TextStyle(color: Colors.white),
                                cursorColor: Colors.white,
                                controller: _storyCaptionController,
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: 3,
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.5),
                                    hintText: LanguageNotifier.of(context)!
                                        .translate('caption'),
                                    hintStyle:
                                        const TextStyle(color: Colors.white),
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10.0, horizontal: 16.0),
                                    border: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                            style: BorderStyle.solid,
                                            color: Color(0xFFFFFFFF),
                                            width: 0.3),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                            style: BorderStyle.solid,
                                            color: Color(0xFFFFFFFF),
                                            width: 0.3),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                            style: BorderStyle.solid,
                                            color: Color(0xFFFFFFFF),
                                            width: 0.3),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    suffixIcon: IconButton(
                                        icon: const Icon(
                                          Icons.send,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _uploadStory(image,
                                              _storyCaptionController.text);
                                        })
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
                      (isVideo &&
                              _videoController != null &&
                              _videoController!.value.isInitialized)
                          ? Positioned(
                              top: MediaQuery.of(context).size.height * 0.4,
                              left: 0,
                              right: 0,
                              child: IconButton(
                                  onPressed: () {
                                    if (_videoController!.value.isPlaying) {
                                      _videoController!.pause();
                                    } else {
                                      _videoController!.play();
                                    }
                                    setState(() => {});
                                  },
                                  icon: Icon(
                                    (_videoController!.value.isPlaying)
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    size: 60,
                                    color: Colors.white.withOpacity(0.6),
                                  )),
                            )
                          : Container(),
                      (isVideo &&
                              _videoController != null &&
                              _videoController!.value.isInitialized)
                          ? Positioned(
                              top: MediaQuery.of(context).size.height * 1.5,
                              left: 0,
                              right: 0,
                              child: VideoProgressIndicator(
                                _videoController!,
                                allowScrubbing: true,
                              ),
                            )
                          : Container(),
                      // (isVideo && _videoController != null &&  _videoController!.value.isInitialized) ? Positioned(
                      //   top: MediaQuery.of(context).size.height * 3,
                      //   left: 0,
                      //   right: 0,
                      //   child: _ControlsOverlay(controller: _videoController!),
                      // ) : Container()
                    ],
                  ),
                )),
          );
        });
      },
    );
  }

  /// UPLOAD STORY
  /// This function uploads the story image
  Future<void> _uploadStory(dynamic image, dynamic caption) async {
    try {
      List<String> videoExtensions = [
        '.mov',
        '.mp4',
        '.webm',
        '.ogg',
        '.avi',
        '.flv',
        '.mpg',
        '.mpeg'
      ];
      //List<String> imageExtensions = ['.jpg', '.jpeg', '.gif', '.png', '.raw', '.bmp', '.tif', '.tiff'];
      String mediaType = 'image';

      String ext = path.extension((image as File).path);
      if (videoExtensions.contains(ext.toLowerCase())) {
        mediaType = 'video';
      }
      if (mediaType == 'video') {
        return;
      }

      setState(() {
        isSavingStory = true;
      });
      // COMPRESS IMAGE
      File? compressedImageFile = await UtilityService().compressAndConvertToFile(image);
      if( compressedImageFile != null ){
        image = compressedImageFile;
      }
      final response = await userManager.createStory(
          image, caption, mediaType, currentUser['uid']);
      if (response['status'] && mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(LanguageNotifier.of(context)!
        //         .translate('story_added_successfully')),
        //   ),
        // );
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
          ),
        );
      }
      if (mounted) {
        setState(() {
          isSavingStory = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
      setState(() {
        isSavingStory = false;
      });
    }
  }

  void _refreshConversation(){
    var seen = Set<dynamic>();
    conversations = conversations.where((chat) => seen.add(chat['_id'])).toList();
    setState(() {});
  }

  void loadImagesInBG( List<dynamic> stories ){
    if( stories.isNotEmpty ){
      stories.forEach(( dynamic story ) {
        UserAvatar(url: userManager.getServerUrl('/').toString()+story['url'], type: 'network', radius: 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    bool isRTL() => Directionality.of(context).index != 0;
    totalUnreadCounter = 0;

    if (conversations.isNotEmpty) {
      conversations.sort((a, b) {
        if (b['messages'].length == 0 || a['messages'].length == 0) return 0;

        String bLastMsgTimestamp = b['messages'][b['messages'].length - 1]['timestamp'] ?? b['updatedAt'];
        String aLastMsgTimestamp = a['messages'][a['messages'].length - 1]['timestamp'] ?? a['updatedAt'];

        DateTime bDt = DateTime.parse(bLastMsgTimestamp);
        DateTime aDt = DateTime.parse(aLastMsgTimestamp);
        return bDt.compareTo(aDt);
      });

      conversations = conversations.map((e) {
        int counter = 0;
        final List messages = e['messages'];
        for (var i = 0; i < messages.length; i++) {
          final message = messages[i];
          List read = message['readBy'] ?? [];
          if (message['sender'] != currentUser['uid'] && !read.contains(currentUser['uid'])) {
            counter = counter+1;
          }
        }
        e['counter'] = counter;
        totalUnreadCounter = (counter > 0) ? totalUnreadCounter + 1 : totalUnreadCounter;
        return e;
      }).toList();
    }

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
                          leading: (isSavingStory)
                              ? Padding(
                            padding: EdgeInsets.only(left: 10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              ],
                            ),
                          )
                              : IconButton(
                              onPressed: () => showCameraDialog(
                                  context, _previewNewStoryDialog,
                                  showGallery: true),
                              icon: Icon(
                                Icons.camera_alt_outlined,
                                color: myColors.appSecTextColor,
                              )),
                          leadingWidth: 50,
                          centerTitle: true,
                          elevation: 0.2,
                          title: Text(
                            LanguageNotifier.of(context)!.translate('messenger'),
                            style: TextStyle(color: myColors.appSecTextColor),
                          ),
                        ),
                        body: (!isSpinning)
                            ? (conversations.isEmpty)
                            ? Center(
                                child: Text(LanguageNotifier.of(context)!
                                    .translate('no_conversation_found')),
                              )
                            : Directionality(
                                textDirection: (isRTL())
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                child: ListView.builder(
                                  itemCount: conversations.length,
                                  // assuming you have a list of chat users
                                  itemBuilder: (context, index) {
                                    final MyColors myColors =
                                    Theme.of(context).extension<MyColors>()!;
                                    final userDistance =
                                        (conversations[index]['distance'] / 1000)
                                            .toStringAsFixed(1) +
                                            ' ' +
                                            LanguageNotifier.of(context)!
                                                .translate('km');
                                    final oUid = conversations[index]
                                    ['otherMemberInfo']['_id'];

                                    final List messages = conversations[index]['messages'];

                                    dynamic otherUser = conversations[index]['otherMemberInfo'];
                                    List otherUserStories = conversations[index]['otherMemberInfo']['stories'] ?? [];
                                    String avatarUrl = (otherUser['avatar']['type'] == 'avatar') ? otherUser['avatar']['url'] : UserManager().getServerUrl('/').toString()+otherUser['avatar']['url'];
                                    loadImagesInBG( otherUserStories );

                                    return ( messages.isNotEmpty ) ? Column(children: [
                                      Slidable(
                                        key: Key(UniqueKey().toString()),
                                        startActionPane: ActionPane(
                                            motion: const ScrollMotion(),
                                            dismissible:
                                            DismissiblePane(onDismissed: () {
                                              showReportDialog(
                                                  context, conversations[index]);
                                            }),
                                            children: [
                                              SlidableAction(
                                                onPressed: (params) => {
                                                  showReportDialog(context,
                                                      conversations[index])
                                                },
                                                backgroundColor:
                                                const Color(0xFFFE4A49),
                                                foregroundColor: Colors.white,
                                                icon: Icons
                                                    .report_gmailerrorred_sharp,
                                                label:
                                                LanguageNotifier.of(context)!
                                                    .translate('report'),
                                              ),
                                            ]),
                                        endActionPane: ActionPane(
                                            motion: const ScrollMotion(),
                                            dismissible:
                                            DismissiblePane(onDismissed: () {
                                              vanishUser(conversations[index]);
                                            }),
                                            children: [
                                              SlidableAction(
                                                onPressed: (action) => vanishUser(
                                                    conversations[index]),
                                                backgroundColor:
                                                const Color(0xFFFE4A49),
                                                foregroundColor: Colors.white,
                                                icon: Icons.block,
                                                label:
                                                LanguageNotifier.of(context)!
                                                    .translate('vanish'),
                                              ),
                                            ]),
                                        child: ListTile(
                                          visualDensity: const VisualDensity(
                                              horizontal: 0, vertical: -3),
                                          leading: GestureDetector(
                                            onTap: () => getUserStories( otherUser, conversations[index] ),
                                            child: FittedBox(
                                              child: Column(
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                                children: <Widget>[
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      boxShadow: (userHasStories( otherUserStories )) ? [
                                                        BoxShadow(
                                                            color: (conversations[index]['background'] as Color), // Shadow color
                                                            blurRadius: 10,
                                                            spreadRadius: 2// Spread radius
                                                          //offset: Offset(0, 3), // Offset in the x and y direction
                                                        ),
                                                      ] : [],
                                                    ),
                                                    child: CircleAvatar(
                                                      backgroundColor: conversations[index]['background'],
                                                      radius: 21.0,
                                                      child: UserAvatar(url: avatarUrl, type: otherUser['avatar']['type'], radius: 19.0),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          title: GestureDetector(
                                            onTap: () => _openChatPage(oUid),
                                            child: Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment.start,
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                    child: Container(
                                                      color: Colors.transparent,
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            conversations[index][
                                                            'otherMemberInfo']
                                                            ['username'],
                                                            style: const TextStyle(
                                                                fontSize: 16),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            userDistance,
                                                            style: const TextStyle(
                                                                fontSize: 14),
                                                          )
                                                        ],
                                                      ),
                                                    )),
                                                (conversations[index]['counter'] >
                                                    0)
                                                    ? Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                      color: myColors
                                                          .brandColor,
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                          100)),
                                                  child: Center(
                                                    child: Text(
                                                      conversations[index]
                                                      ['counter']
                                                          .toString(),
                                                      style:
                                                      const TextStyle(
                                                          color: Colors
                                                              .white,
                                                          fontSize: 13),
                                                    ),
                                                  ),
                                                )
                                                    : Container(),
                                              ],
                                            ),
                                          ),
                                          subtitle: GestureDetector(
                                            onTap: () => _openChatPage(oUid),
                                            child: Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment.start,
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                    child: Text(
                                                      getLastMessage(
                                                        conversations[index]
                                                        ['messages'],
                                                      ),
                                                      style: TextStyle(
                                                          fontWeight: ((conversations[
                                                          index]
                                                          ['counter'] >
                                                              0))
                                                              ? FontWeight.bold
                                                              : FontWeight.normal),
                                                      overflow: TextOverflow.ellipsis,
                                                    )),
                                                Text(timeSince(
                                                    conversations[index]
                                                    ['messages'])),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Divider(
                                          height: 2, color: Colors.grey),
                                    ]) : Container();
                                  },
                                ),
                              )
                            : const Center(
                            child: CircularProgressIndicator(),
                        ),
                        bottomNavigationBar: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(25),
                                topLeft: Radius.circular(25)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12, spreadRadius: 0, blurRadius: 10),
                            ],
                            color: myColors.appSecBgColor,
                          ),
                          //notchedShape: CircularNotchedRectangle(),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
                                      showBadge: (totalUnreadCounter > 0) ? true : false,
                                      position:
                                      badges.BadgePosition.topEnd(top: 5, end: 0),
                                      badgeContent: Text(
                                        totalUnreadCounter.toString(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      child: IconButton(
                                        icon: SvgPicture.asset(
                                          'assets/speech.svg',
                                          colorFilter: const ColorFilter.mode(
                                              Colors.white, BlendMode.srcIn),
                                        ),
                                        onPressed: null,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        // StorageManager.saveData(
                                        //     'home-tab', (homeTab == 0) ? 1 : 0);
                                        Navigator.of(context)
                                            .popUntil(ModalRoute.withName("/home"));
                                      },
                                      //Navigator.pop(context, '/home'),
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
                                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/menu',
                                        ModalRoute.withName('/home'),
                                      ),
                                      icon: SvgPicture.asset(
                                        'assets/profile.svg',
                                        colorFilter: const ColorFilter.mode(
                                            Colors.white, BlendMode.srcIn),
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
                          ),
                        ),
                      ),
                    )),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (details.delta.dx < 10) {
                        Navigator.pop(context);
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
                  child: UtilityService().handleCustomAlerts(
                    context: context,
                    user: currentUser,
                    ss: ss,
                    callback: loadChats,
                    setState: setState,
                    privacyDisabled: locationManager.isPrivacyDisabled
                  )
                ),
                // (!ss.socket.connected) ? Positioned(
                //     child: UtilityService().showDisconnectDialog('', context, ( void Function() ) => {})
                // ) :
                // ((!permissionManager.isLocationPermissionGranted || !permissionManager.isLocationServiceEnabled) && !locationManager.isLocationDenied ) ? Positioned(
                //     child: UtilityService().showLocationAlertDialog(
                //         context,
                //         currentUser,
                //         loadChats,
                //         type: 'permission'
                //     )
                // ) :
                // (!locationManager.isLocationPermissionGranted && !locationManager.isLocationDenied ) ? Positioned(
                //     child: UtilityService().showLocationAlertDialog(context, currentUser, loadChats)
                // ) : Container(),
              ],
            ),
          );
        }
    );
  }
}
