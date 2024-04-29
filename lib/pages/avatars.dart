import 'package:flutter/material.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';

class Avatars extends StatefulWidget {
  const Avatars({Key? key}) : super(key: key);

  @override
  State<Avatars> createState() => _AvatarsState();
}

class _AvatarsState extends State<Avatars> {
  // Define a list of avatars
  final List<String> _avatars = [
    'assets/avatars/avatar_1.png',
    'assets/avatars/avatar_2.png',
    'assets/avatars/avatar_3.png',
    'assets/avatars/avatar_4.png',
    'assets/avatars/avatar_5.png',
    'assets/avatars/avatar_6.png',
    'assets/avatars/avatar_7.png',
    'assets/avatars/avatar_8.png',
    'assets/avatars/avatar_9.png',
    'assets/avatars/avatar_10.png',
    'assets/avatars/avatar_11.png',
    'assets/avatars/avatar_12.png',
    'assets/avatars/avatar_13.png',
    'assets/avatars/avatar_14.png',
    'assets/avatars/avatar_15.png',
    'assets/avatars/avatar_16.png',
    'assets/avatars/avatar_17.png',
    'assets/avatars/avatar_18.png',
    'assets/avatars/avatar_19.png',
    'assets/avatars/avatar_20.png',
  ];

  // Define a set to keep track of selected avatars
  String _selectedAvatars = '';

  Widget _showButton( context ) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    if (_selectedAvatars.isEmpty) {
      return Container();
    } else {
      return Container(
        padding: const EdgeInsets.only(bottom: 20.0),
        width: MediaQuery
            .of(context)
            .size
            .width * 0.9,
        child: FloatingActionButton.extended(
          backgroundColor: myColors.brandColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)
          ),
          onPressed: () => Navigator.pop(context, _selectedAvatars),
          label: Text(LanguageNotifier.of(context)!.translate('continue')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: myColors.appSecBgColor,
        appBar: AppBar(
          backgroundColor: myColors.appSecBgColor,
          leading: IconButton(
            color: myColors.appSecTextColor,
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(LanguageNotifier.of(context)!.translate('choose_avatar'), style: TextStyle(color: myColors.appSecTextColor),),
          centerTitle: true,
          elevation: 0.2,
        ),
        body: GridView.builder(
          itemCount: _avatars.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  if( identical(_selectedAvatars, _avatars[index]) ){
                    _selectedAvatars = '';
                  }else{
                    _selectedAvatars = _avatars[index];
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFECECEC),
                    border: Border.all(
                      color: (identical(_selectedAvatars, _avatars[index])) ? myColors.brandColor! : Colors.transparent,
                      width: 3.0,
                    ),
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: Image.asset(
                    _avatars[index],
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButton: _showButton(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}
