import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/utlityService.dart';
import 'package:radius_app/widgets/userAvatar.dart';

import '../services/themeManager.dart';

class PreviewStories extends StatefulWidget {
  String username = '';       // User name
  String avatarType = '';     // User Avatar Type ( Local, Network)
  String avatarUrl  = '';     // User Avatar Url
  bool   onHold     = false;  // Is user holding the dialog & dragging
  String whoIm      = 'self'; // Is user the owner or someone else
  List<dynamic> storiesList;  // Stories
  final ValueChanged<dynamic> onAction; // On end story list perform auto close action
  final ValueChanged<dynamic> onReportAction;

  PreviewStories({Key? key, required this.whoIm, required this.onHold, required this.onAction, required this.onReportAction, required this.storiesList, required this.username, required this.avatarType, required this.avatarUrl}) : super(key: key);

  @override
  State<PreviewStories> createState() => _PreviewStoriesState();
}

class _PreviewStoriesState extends State<PreviewStories> with TickerProviderStateMixin {
  UserManager userManager = UserManager();
  String username = '';
  dynamic avatar = { "type" : '', "url" : "" };
  int currentIndex = 0;
  List<dynamic> stories = [];
  List<dynamic> storyControllers = [];
  AnimationController? storyController;
  Timer? _storyTimer;
  double storyProgressValue = 0.0;
  bool isOnHold = false;
  bool isLongPressed = false;
  bool isContentLoaded = false;

  @override
  void initState() {
    super.initState();
    stories = widget.storiesList;
    username= widget.username;
    avatar = { "type" : widget.avatarType, "url" : widget.avatarUrl };
    _startStoryTimer();
  }

  void nextStory(){
    if( currentIndex < (stories.length-1) ){
      _startStoryTimer();
      setState(() {
        currentIndex++;
      });
    }else{
      widget.onAction( null );
    }
  }

  void prevStory(){
    if( currentIndex > 0 ){
      _startStoryTimer();
      setState(() {
        currentIndex--;
      });
    }
  }

  void _startStoryTimer(){
    _storyTimer?.cancel();
    storyController?.dispose();
    storyProgressValue = 0.0;

    storyController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..addListener(() {
      setState(() {});
    })..repeat(reverse: false);

    _storyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if( !isOnHold && !widget.onHold && isContentLoaded){
        storyController?.forward(from: storyController?.value );
        storyProgressValue += 0.10;
        if( storyProgressValue == 1.0 || storyProgressValue == 1 || storyProgressValue > 1 ){
          _storyTimer?.cancel();
          nextStory();
        }
        //setState(() {});
      }else{
        storyController?.stop();
      }
    });
  }

  Widget getProgressbar( int count ){

    List<Widget> progressBars = [];

    for( int i=0; i<count; i++ ){
      progressBars.add( Expanded(
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ),
          builder: (context, value, _) =>
              LinearProgressIndicator(
                minHeight: 1.5,
                backgroundColor: Colors.white.withOpacity(0.6),
                color: Colors.white,
                value: ( i >= currentIndex ) ? ( i == currentIndex ) ? storyController?.value : 0.0 : 1.0,
              ),
        ),
        // child: LinearProgressIndicator(
        //   minHeight: 1.5,
        //   backgroundColor: Colors.white.withOpacity(0.6),
        //   color: Colors.white,
        //   value: ( i >= currentIndex ) ? ( i == currentIndex ) ? storyProgressValue : 0.0 : 1.0,
        // ),
      ));
      if( count > 1 && i != count - 1 ){
        progressBars.add( const SizedBox(width: 5,));
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: progressBars,
    );
  }

  Future<void> _showAlertDialog(BuildContext context, { String type = 'user', String title = '', String storyId = '' }) async {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    TextEditingController textController = TextEditingController();

    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(LanguageNotifier.of(context)!.translate(title)),
            content: StatefulBuilder(
                builder: (context, setState) {
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: textController,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            labelText: LanguageNotifier.of(context)!.translate('reason'),
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
                          ),
                          onChanged: (value) {},
                        ),
                      ],
                    ),
                  );
                }
            ),
            actions: <Widget>[
              TextButton(
                child: Text(LanguageNotifier.of(context)!.translate('cancel')),
                onPressed: () {
                  setState(() {
                    isOnHold = false;
                  });
                  Navigator.of(context).pop();
                },
              ),
              FilledButton(
                child: Text(LanguageNotifier.of(context)!.translate('report')),
                onPressed: () async {
                  Navigator.of(context).pop();
                  widget.onReportAction( { "action" : type, "username" : widget.username, "reason": textController.text, "storyId" : storyId } );
                },
              ),
            ],
          );
    });
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    storyController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if( stories.isEmpty ){
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(LanguageNotifier.of(context)!.translate('no_story_found'), style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          decoration: TextDecoration.none,
              fontWeight: FontWeight.normal
          )),
        ),
      );
    }
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    String caption = stories[currentIndex]['caption'] ?? '';
    String time = UtilityService().getStoryTime( stories[currentIndex]['uploadedOn'] );

    // if( stories[currentIndex]['createdUserDate']!=null && stories[currentIndex]['createdUserDate']!='' ){
    //   dateTime = DateFormat("yyyy-MM-ddTHH:mm:ssZ").parse(stories[currentIndex]['createdUserDate']);
    //   time = DateFormat("h:mm a").format(dateTime);
    // }else{
    //   dateTime = DateFormat("yyyy-MM-ddTHH:mm:ssZ").parse(stories[currentIndex]['uploadedOn']);
    //   time = DateFormat("h:mm a").format(dateTime);
    // }

    String currentStoryId = stories[currentIndex]['_id'];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: userManager.getServerUrl('/').toString()+stories[currentIndex]['url'],
                imageBuilder: (context, imageProvider) { // you can access to imageProvider
                  isContentLoaded = true;
                  return Image(image: imageProvider);
                },
                progressIndicatorBuilder: (context, url, downloadProgress){
                  if (downloadProgress.progress == null ){
                    isContentLoaded = true;
                  }else{
                    isContentLoaded = false;
                  }
                  return Center(child: CircularProgressIndicator( value: downloadProgress.progress ));
                },
                errorWidget: (context, url, error){
                  isContentLoaded = true;
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, color: Colors.white, size: 72,),
                        //Text("Image not found", style: TextStyle(color: Colors.white, ),)
                      ],
                    ),
                  );
                },
              ),
              //   child: Image.network(
              //     userManager.getServerUrl('/').toString()+stories[currentIndex]['url'],
              //     loadingBuilder: (BuildContext context, Widget child,
              //         ImageChunkEvent? loadingProgress) {
              //       if (loadingProgress == null){
              //         isContentLoaded = true;
              //         return child;
              //       }
              //       isContentLoaded = false;
              //       return Center(
              //         child: CircularProgressIndicator(
              //           color: myColors.brandColor!,
              //           value: loadingProgress.expectedTotalBytes != null
              //               ? loadingProgress.cumulativeBytesLoaded /
              //               loadingProgress.expectedTotalBytes!
              //               : null,
              //         ),
              //       );
              //     },
              //   )
            ),
            /// PREVIOUS STORY BUTTON
            Positioned(
                top: 0, left: 0,
                child: GestureDetector(
                  onLongPressStart: ( details )  {
                    setState(() { isOnHold = true; });
                  },
                  onLongPressEnd: (detail){
                    setState(() { isOnHold = false; });
                  },
                  onTap: () => prevStory(),
                  child: Container(
                    color: Colors.transparent,
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height,
                  ),
                )
            ),
            /// NEXT STORY BUTTON
            Positioned(
                top: 0, right: 0,
                child: GestureDetector(
                  onLongPressStart: ( details )  {
                    setState(() { isOnHold = true; });
                  },
                  onLongPressEnd: (detail){
                    setState(() { isOnHold = false; });
                  },
                  onTap: () => nextStory(),
                  child: Container(
                    color: Colors.transparent,
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height,
                  ),
                )
            ),
            /// STORY CAPTION
            (caption.isNotEmpty) ? Positioned(
                bottom: 60,
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.black.withOpacity(0.2),
                  width: MediaQuery.of(context).size.width,
                  padding: const EdgeInsets.all(10),
                  child: Text(caption, style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w300
                  ),
                  ),
                )
            ) : Container(),
            /// PROGRESS BAR
            (isOnHold) ? Container() : Positioned(
                top: 50,
                child: Container(
                  color: Colors.transparent,
                  width: MediaQuery.of(context).size.width * 0.95,
                  child: getProgressbar( stories.length ),
                )
            ),
            /// USER INFORMATION
            Positioned(
                top: 70,
                child: Container(
                  color: Colors.transparent,
                  width: MediaQuery.of(context).size.width * 0.95,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 20.0,
                          child: UserAvatar(
                            url:  ( widget.avatarType == 'network' ) ? userManager.getServerUrl('/').toString()+widget.avatarUrl : widget.avatarUrl,
                            type: widget.avatarType,
                            radius: 19.0
                          ),
                        ),
                        const SizedBox(width: 10,),
                        Expanded(child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.username, style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                decoration: TextDecoration.none,
                                fontWeight: FontWeight.normal
                            )),
                            const SizedBox(height: 3,),
                            Text(time, style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                decoration: TextDecoration.none,
                                fontWeight: FontWeight.normal
                            )),
                          ],
                        )),
                        (widget.whoIm == 'self' ) ? Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          elevation: 4,
                          color: Colors.transparent,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white,),
                            iconSize: 30,
                            position: PopupMenuPosition.under,
                            offset: const Offset(-10, 10),
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
                                    Icons.delete,
                                    color: myColors.appSecTextColor!,
                                  ),
                                  const SizedBox(
                                    width: 15.0,
                                  ),
                                  Text(LanguageNotifier.of(context)!.translate('delete')),
                                ]),
                                onTap: () async {},
                              ),
                            ],
                            onSelected: ( value ){
                              widget.onAction( { "action" : "delete", "_id" : currentStoryId, "url" : stories[currentIndex]['url'] } );
                              if( currentIndex == 0 ){
                                nextStory();
                              }else{
                                prevStory();
                              }
                            },
                          ),
                        ) : Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          elevation: 4,
                          color: Colors.transparent,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white,),
                            iconSize: 30,
                            position: PopupMenuPosition.under,
                            offset: const Offset(-10, 10),
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10.0))
                            ),
                            itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem(
                                value: 'report_story',
                                child: Row(children: <Widget>[
                                  Icon(
                                    Icons.report_gmailerrorred_sharp,
                                    color: myColors.appSecTextColor!,
                                  ),
                                  const SizedBox(
                                    width: 15.0,
                                  ),
                                  Text(LanguageNotifier.of(context)!.translate('report_story')),
                                ]),
                                onTap: () async {},
                              ),
                              PopupMenuItem(
                                value: 'report_user',
                                child: Row(children: <Widget>[
                                  Icon(
                                    Icons.report_gmailerrorred_sharp,
                                    color: myColors.appSecTextColor!,
                                  ),
                                  const SizedBox(
                                    width: 15.0,
                                  ),
                                  Text(LanguageNotifier.of(context)!.translate('report_user')),
                                ]),
                                onTap: () async {},
                              ),
                              PopupMenuItem(
                                value: 'vanish_user',
                                child: Row(children: <Widget>[
                                  Icon(
                                    Icons.report_gmailerrorred_sharp,
                                    color: myColors.appSecTextColor!,
                                  ),
                                  const SizedBox(
                                    width: 15.0,
                                  ),
                                  Text(LanguageNotifier.of(context)!.translate('vanish_user')),
                                ]),
                                onTap: () async {},
                              ),
                            ],
                            onSelected: ( value ){
                              isOnHold = true;
                              if( value == 'report_story'){
                                _showAlertDialog(context, type: value, title: 'report_story', storyId: currentStoryId);
                              }
                              else if( value == 'report_user'){
                                _showAlertDialog(context, type: value, title: 'report_user');
                              }
                              else if( value == 'vanish_user'){
                                widget.onReportAction( { "action" : value, "username" : widget.username } );
                              }
                            },
                          ),
                        ),
                      ],
                  ),
                )
            ),
          ],
        ),
      ),
    );
  }
}
