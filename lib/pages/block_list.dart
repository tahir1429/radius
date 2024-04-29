import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:radius_app/widgets/userAvatar.dart';
import 'package:radius_app/services/permissionManager.dart';

class BlockList extends StatefulWidget {
  const BlockList({Key? key}) : super(key: key);

  @override
  State<BlockList> createState() => _BlockListState();
}

class _BlockListState extends State<BlockList> {
  // User Manager Service Instance
  UserManager userManager = UserManager();
  // Current Logged-in User Object
  dynamic currentUser;
  // Blocked User List
  List blockedList = [];
  // Spinner Status
  bool isSpinning = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // Get User Blocked List
    getBlockedList();
  }

  /// GET USER BLOCK LIST
  void getBlockedList() async {
    // Get Current user from local storage
    currentUser = await StorageManager.getUser();
    if( currentUser != null ){
      // Get User Blocked List
      final response = await userManager.getBlockedList( currentUser['uid'] );
      if( response['status'] ){
        blockedList = response['users'] as List;
      }
    }
    // Stop Spinner
    setState(() { isSpinning = false; });
  }

  /// UN-VANISH USER
  void unVanish( dynamic user ) async {
    // Unblock-User
    final response = await userManager.toggleBlock( currentUser['uid'], user['_id'], status: false );
    if( response['status'] ){
      // Remove user from existing blocked list
      blockedList.removeWhere((item) => item['_id'] == user['_id'] );
    }
    // Refresh Build
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Get theme custom colors
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    // Check if screen Direction is RTL or LTR
    bool isRTL() => Directionality.of(context).index != 0;

    return Consumer<PermissionManager>(
        builder: (context, permissionManager, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Scaffold(
                  backgroundColor: myColors.appSecBgColor,
                  appBar: AppBar(
                    backgroundColor: myColors.appSecBgColor,
                    leading: IconButton(
                      color: myColors.appSecTextColor,
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => Navigator.pop(context),
                    ),
                    centerTitle: true,
                    title: Text(LanguageNotifier.of(context)!.translate('vanished_list'), style: TextStyle(color: myColors.appSecTextColor), ),
                  ),
                  body : ( isSpinning ) ? const Center( child: CircularProgressIndicator(),) : (blockedList.isEmpty) ?  Center( child: Text(LanguageNotifier.of(context)!.translate('empty')),) : Directionality(
                    textDirection: (isRTL()) ? TextDirection.ltr : TextDirection.rtl,
                    child: ListView.builder(
                      itemCount: blockedList.length, // assuming you have a list of chat users
                      itemBuilder: (context, index) {
                        // Get user avatar
                        String avatarUrl = ( blockedList[index]['avatar']['type'] == 'avatar') ?  blockedList[index]['avatar']['url'] : UserManager().getServerUrl('/').toString()+ blockedList[index]['avatar']['url'];

                        return Column(
                            children: [
                              Slidable(
                                key: Key(UniqueKey().toString()),
                                endActionPane: ActionPane(
                                    motion: const ScrollMotion(),
                                    dismissible: DismissiblePane(onDismissed: () {
                                      unVanish( blockedList[index] );
                                    }),
                                    children : [
                                      SlidableAction(
                                        // Un-Vanish user on slide/press
                                        onPressed: ( action ) => unVanish( blockedList[index] ),
                                        backgroundColor: const Color(0xFF007500),
                                        foregroundColor: Colors.white,
                                        icon: Icons.check,
                                        label: LanguageNotifier.of(context)!.translate('un_vanish'),
                                      ),
                                    ]
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric( vertical: 10, horizontal: 15 ),
                                  leading: FittedBox(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget> [
                                        CircleAvatar(
                                          backgroundColor: Colors.grey,
                                          radius: 35.0,
                                          child: UserAvatar(url: avatarUrl, type: blockedList[index]['avatar']['type'], radius: 31.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                  //title: Text(chatUsers[index].name),
                                  title: Text( blockedList[index]['username'] ),
                                ),
                              ),
                              const Padding (
                                padding: EdgeInsets.symmetric(horizontal: 15.0),
                                child: Divider(height: 2, color: Colors.grey),
                              ),
                            ]
                        );
                      },
                    ),
                  ),
                ),
                ),
              ],
            ),
          );
        }
    );
  }
}
