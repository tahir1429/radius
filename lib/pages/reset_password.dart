import 'package:flutter/material.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/userManager.dart';

class ResetPassword extends StatefulWidget {
  final dynamic data;
  const ResetPassword({Key? key, required this.data}) : super(key: key);

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  UserManager userManager = UserManager();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController passwordController = TextEditingController();
  TextEditingController cfnPasswordController = TextEditingController();
  dynamic currentUser;
  bool showSpinner = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getUserInfo();
  }

  void getUserInfo() async {
    final response = await userManager.getUserByEmail( widget.data['email'] );
    if( response['status'] && mounted ){
      setState(() {
        currentUser = response['user'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return WillPopScope(
        onWillPop: () async { Navigator.pushReplacementNamed(context, 'sign-in'); return true; } ,
        child: Scaffold(
      backgroundColor: myColors.appSecBgColor,
      appBar: AppBar(
        backgroundColor: myColors.appSecBgColor,
        title: Text(LanguageNotifier.of(context)!.translate('reset_password'), style: TextStyle(color: myColors.appSecTextColor),),
        centerTitle: true,
        leading: IconButton(
          color: myColors.appSecTextColor,
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
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
                      final response = await UserManager().updatePassword( currentUser['_id'], passwordController.text );
                      if( response['status'] && mounted ){
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LanguageNotifier.of(context)!.translate('success_reset_pass')),
                          ),
                        );
                        Navigator.pushNamed(context, '/sign-in');
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
