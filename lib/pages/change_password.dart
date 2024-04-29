import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/pages/sign_in.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({Key? key}) : super(key: key);

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  UserManager userManager = UserManager();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController passwordController = TextEditingController();
  TextEditingController cfnPasswordController = TextEditingController();
  bool showSpinner = false;
  dynamic currentUser;

  @override
  void initState() {
    super.initState();
    getUser();
  }

  Future<void> getUser() async {
    final response = await StorageManager.getUser();
    if (response != null && response['username'] != null && mounted) {
      currentUser = response;
      setState(() {});
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignIn()),
              (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Scaffold(
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
            LanguageNotifier.of(context)!.translate('change_password'),
            style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16.0,color: myColors.appSecTextColor),
          ),
          elevation: 0.2,
        ),
        body: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(LanguageNotifier.of(context)!.translate('new_password'), style: const TextStyle(fontWeight: FontWeight.w700),),
                  const SizedBox(height: 10,),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: myColors.appSecBgColor,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: LanguageNotifier.of(context)!.translate('new_password_hint'),
                    ),
                    validator: ( value ){
                      RegExp regex=RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9]).{8,}$');
                      if( value!.isEmpty ){
                        return LanguageNotifier.of(context)!.translate('error_pass_required');
                      }
                      else if (value.length < 8) {
                        return LanguageNotifier.of(context)!.translate('error_pass_length');
                      }
                      else if(!regex.hasMatch(value)){
                        return LanguageNotifier.of(context)!.translate('error_pass_strength');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20,),
                  Text(LanguageNotifier.of(context)!.translate('cfn_password'), style: const TextStyle(fontWeight: FontWeight.w700),),
                  const SizedBox(height: 10,),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: cfnPasswordController,
                    obscureText: true,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: myColors.appSecBgColor,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: LanguageNotifier.of(context)!.translate('cfn_password_hint'),
                    ),
                    validator: ( value ){
                      if( value!.isEmpty ){
                        return LanguageNotifier.of(context)!.translate('error_cfn_required');
                      }
                      if( value != passwordController.text ){
                        return LanguageNotifier.of(context)!.translate('error_pass_mismatch');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: MediaQuery.of(context).size.width*1,
                    child: FilledButton(
                      onPressed: () async {
                        if ( formKey.currentState!.validate() && !showSpinner ) {
                          /// Show Loader
                          setState(() { showSpinner = true; });
                          /// Update Password
                          final response = await UserManager().updatePassword( currentUser['uid'], passwordController.text );
                          if( response['status'] && mounted ){
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully'),
                              ),
                            );
                          }else{
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error occurred'),
                              ),
                            );
                          }
                          setState(() { showSpinner = false; });
                        }
                      },
                      child: (showSpinner) ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator( strokeWidth: 3, color: Colors.white,),
                      ) : Text(LanguageNotifier.of(context)!.translate('set_password'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
    );
  }
}
