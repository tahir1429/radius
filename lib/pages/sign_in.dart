import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/locationManager.dart';

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  UserManager userManager = UserManager();
  StorageManager storageManager = StorageManager();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  String email = '';
  String password = '';
  bool showSpinner = false;
  String errorMsg = '';
  bool isPasswordVisible = false;
  dynamic selectedCountryCode = '+996'; // default country code

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;
    emailController.text = email;
    passwordController.text = password;
    passwordController.selection = TextSelection.fromPosition(TextPosition(offset: password.length,));

    return Scaffold(
      backgroundColor: myColors.appSecBgColor,
      body: Center(
        child: (showSpinner)  ? const CircularProgressIndicator() : Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 30.0,),
                  Text(
                    LanguageNotifier.of(context)!.translate('sign_in_heading'),
                    style: TextStyle(
                        color: myColors.appSecTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 22.0
                    ),
                  ),
                  const SizedBox(height: 30.0,),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 16.0, height: 1.0),
                    decoration: InputDecoration(
                      labelText: LanguageNotifier.of(context)!.translate('email_hint'),
                      hintText: LanguageNotifier.of(context)!.translate('email_hint'),
                      prefixIcon: const Icon(Icons.markunread),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: ( value ){
                      email = value;
                    },
                    validator: (value) {
                      if (value!.isEmpty) {
                        return LanguageNotifier.of(context)!.translate('error_email_required');
                      }
                      else if ( !value.contains('@') || !value.contains('.') ) {
                        return LanguageNotifier.of(context)!.translate('error_email_invalid');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0,),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    style: const TextStyle(fontSize: 16.0, height: 1.0),
                    decoration: InputDecoration(
                      labelText: LanguageNotifier.of(context)!.translate('password_hint'),
                      hintText: LanguageNotifier.of(context)!.translate('password_hint'),
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          (isPasswordVisible)
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    onChanged: ( value ){
                      password = value;
                    },
                    validator: (value) {
                      if (value!.isEmpty) {
                        return LanguageNotifier.of(context)!.translate('error_pass_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0,),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/forgot-password'),
                    child: Text(LanguageNotifier.of(context)!.translate('forgot_password'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.0, color: Color(0xFFC835C1)),),
                  ),
                  const SizedBox(height: 20.0,),
                  (errorMsg != '') ? Container(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: Text(errorMsg, style: const TextStyle(color: Colors.red),),
                  ) : Container(),
                  SizedBox(
                    width: MediaQuery.of(context).size.width*0.9,
                    child: FilledButton(
                      onPressed: () async {
                        errorMsg = '';
                        if ( formKey.currentState!.validate() && mounted ) {
                          setState(() {
                            showSpinner = true;
                            errorMsg = '';
                          });
                          final account = await userManager.login( email.toLowerCase(), password );
                          if( account['status'] ){
                            StorageManager.saveData('app-opened', true);
                            StorageManager.saveData('location-enabled', false );
                            StorageManager.saveData('location-denied', false );
                            StorageManager.saveData('privacy-disabled', false );
                            StorageManager.saveUser( account['user'], jwtToken: account['token'] );
                            if( mounted ){
                              Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
                              Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( false );
                              if( account['user']['username'] == null || account['user']['username'] == '' ){
                                Navigator.pushNamed(context, '/setup-avatar');
                              }else{
                                Navigator.pushNamed(context, '/home');
                              }
                            }
                          }else{
                            if( mounted ){
                              errorMsg = LanguageNotifier.of(context)!.translate('error_credentials');
                            }
                          }
                          if( mounted ){
                            showSpinner = false;
                            setState(() {});
                          }
                        }
                      },
                      child: Text(LanguageNotifier.of(context)!.translate('sign_in'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
                    ),
                  ),
                  const SizedBox(height: 20.0,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(LanguageNotifier.of(context)!.translate('no_account')),
                      const SizedBox(width: 5.0,),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/sign-up'),
                        child: Text(LanguageNotifier.of(context)!.translate('sign_up'), style: const TextStyle(color: Color(0xFFC835C1), fontWeight: FontWeight.w700),),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
