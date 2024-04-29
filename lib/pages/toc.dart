import 'package:flutter/material.dart';
import 'package:radius_app/services/languageManager.dart';

import '../services/themeManager.dart';

class Toc extends StatelessWidget {
  const Toc({Key? key}) : super(key: key);

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
            icon: const Icon(Icons.arrow_back_ios),// set the color of the back button here
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            LanguageNotifier.of(context)!.translate('toc'),
            style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16.0,color: myColors.appSecTextColor),
          ),
          elevation: 0.2,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              LanguageNotifier.of(context)!.translate('toc_text'),
              style: const TextStyle(fontSize: 16.0,),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
