import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:radius_app/services/themeManager.dart';

class UserAvatar extends StatefulWidget {
  String url;
  String type;
  double radius;
  File? file;

  UserAvatar({
    Key? key,
    required this.url, this.file, required this.type, required this.radius}) : super(key: key);

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    switch( widget.type ){
      case 'network':
        return CachedNetworkImage(
          imageUrl: widget.url,
          imageBuilder: (context, imageProvider) { // you can access to imageProvider
            return CircleAvatar(
              radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
              backgroundColor: myColors.borderColor!.withOpacity(0.5),
              backgroundImage: imageProvider,
            );
          },
          progressIndicatorBuilder: (context, url, downloadProgress){
            return CircleAvatar(
              radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
              backgroundColor: Colors.white,
              backgroundImage: ( widget.file == null ) ? const AssetImage('assets/app_icon.png') : FileImage(widget.file!) as dynamic,
              child: CircularProgressIndicator( value: downloadProgress.progress ),
            );
          },
          errorWidget: (context, url, error) => CircleAvatar(
            radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
            backgroundColor: Colors.white,
            backgroundImage: const AssetImage('assets/app_icon.png'),
            //child: CircularProgressIndicator(),
          ),
        );

      case 'selected':
        return CircleAvatar(
          backgroundColor: Colors.white,
          backgroundImage: FileImage(widget.file!),
          radius: widget.radius,
        );

      default:
        return CircleAvatar(
          backgroundColor: Colors.white,
          backgroundImage: AssetImage( widget.url ),
          radius: widget.radius,
        );
    }

    return ( widget.type == 'network' ) ? CachedNetworkImage(
      imageUrl: widget.url,
      imageBuilder: (context, imageProvider) { // you can access to imageProvider
        return CircleAvatar(
          radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
          backgroundColor: myColors.borderColor!.withOpacity(0.5),
          backgroundImage: imageProvider,
        );
      },
      progressIndicatorBuilder: (context, url, downloadProgress){
        return CircleAvatar(
          radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
          backgroundColor: Colors.white,
          backgroundImage: ( widget.file == null ) ? const AssetImage('assets/app_icon.png') : FileImage(widget.file!) as dynamic,
          child: CircularProgressIndicator( value: downloadProgress.progress ),
        );
      },
      errorWidget: (context, url, error) => CircleAvatar(
        radius: widget.radius,// or any widget that use imageProvider like (PhotoView)
        backgroundColor: Colors.white,
        backgroundImage: const AssetImage('assets/app_icon.png'),
        //child: CircularProgressIndicator(),
      ),
    ) :
    ( widget.type == 'selected' ) ? CircleAvatar(
      backgroundColor: Colors.white,
      backgroundImage: FileImage(widget.file!),
      radius: widget.radius,
    ) :
    CircleAvatar(
      backgroundColor: Colors.white,
      backgroundImage: AssetImage( widget.url ),
      radius: widget.radius,
    );
  }
}
