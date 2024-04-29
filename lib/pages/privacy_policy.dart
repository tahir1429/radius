import 'package:flutter/material.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/themeManager.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {

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
            LanguageNotifier.of(context)!.translate('privacy_policy'),
            style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16.0,color: myColors.appSecTextColor),
          ),
          elevation: 0.2,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              LanguageNotifier.of(context)!.translate('privacy_policy_text'),
              style: const TextStyle(fontSize: 16.0,),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
