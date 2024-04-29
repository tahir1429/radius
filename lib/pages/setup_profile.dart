import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/pages/setup_avatar.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/userManager.dart';

class SetupProfile extends StatefulWidget {
  final dynamic data;
  const SetupProfile({Key? key, required this.data}) : super(key: key);

  @override
  State<SetupProfile> createState() => _SetupProfileState();
}

class _SetupProfileState extends State<SetupProfile> {
  UserManager userManager = UserManager();
  final formKey = GlobalKey<FormState>();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController cfnPasswordController = TextEditingController();
  Timer? searchOnStoppedTyping;
  bool isUsernameAvailable = true;
  bool isVerifyingUsername = false;
  bool isPasswordVisible = false;

  bool isRTL() => Directionality.of(context).index != 0;

  _onChangeHandler(value ) {
    const duration = Duration(milliseconds:800); // set the duration that you want call search() after that.
    if (searchOnStoppedTyping != null) {
      searchOnStoppedTyping!.cancel();
      setState(() => {}); // clear timer
    }
    searchOnStoppedTyping = Timer(duration, () => checkUserName(value) );
    isVerifyingUsername = false;
    setState(() => {});
  }

  checkUserName( String username ) async {
    setState(() => isVerifyingUsername = true);
    final response = await userManager.isUsernameTaken(username);
    if( response['status'] ){
      isUsernameAvailable = !response['exist'];
    }else{
      isUsernameAvailable = false;
    }
    setState(() => isVerifyingUsername = false);
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Consumer<ThemeNotifier>(
      builder: (context, theme, _) => Scaffold(
        backgroundColor: myColors.appSecBgColor,
        body: Stack(
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Image.asset((theme.isLightMode) ? 'assets/videos/3-light.gif' : 'assets/videos/3-dark.gif', color: Colors.white.withOpacity(0.8), colorBlendMode: BlendMode.modulate,),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10,),
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: usernameController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            FilteringTextInputFormatter(RegExp(r'[a-z0-9._]'), allow: true)
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            labelText:LanguageNotifier.of(context)!.translate('username'),
                            hintText: LanguageNotifier.of(context)!.translate('username_hint'),
                          ),
                          validator: ( value ){
                            if( value!.isEmpty ){
                              return LanguageNotifier.of(context)!.translate('error_username_required');
                            }
                            return null;
                          },
                          onChanged: ( value ) => _onChangeHandler(value),
                        ),
                        const SizedBox(height: 10,),
                        Text(LanguageNotifier.of(context)!.translate('username_type')),

                        ( isVerifyingUsername )
                            ?
                          Container( padding: const EdgeInsets.only(top: 10), child: Row( children: const [ SizedBox(width: 20, height: 20, child: CircularProgressIndicator( strokeWidth: 3,), ), SizedBox(width: 10), Text('Verifying username') ], ),)
                          :
                          ( isUsernameAvailable )
                              ?
                          Container(
                            padding: const EdgeInsets.only(top: 10),
                            child: ( usernameController.text.isNotEmpty ) ? Row( children: [ const Icon(Icons.check), Text(LanguageNotifier.of(context)!.translate('success_username')) ], ) : Container(),
                          )
                              :
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row( children: [ const Icon(Icons.close, color: Colors.red,), Text(LanguageNotifier.of(context)!.translate('error_username_taken'), style: const TextStyle(color: Colors.red),) ], )
                          ),
                        const SizedBox(height: 20,),
                        const SizedBox(height: 10,),
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            labelText:LanguageNotifier.of(context)!.translate('new_password'),
                            hintText: LanguageNotifier.of(context)!.translate('new_password_hint'),
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
                        const SizedBox(height: 10,),
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: cfnPasswordController,
                          obscureText: true,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            labelText:LanguageNotifier.of(context)!.translate('cfn_password'),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Container(
          padding: const EdgeInsets.only(bottom: 20.0),
          width: MediaQuery.of(context).size.width*0.9,
          child: FloatingActionButton.extended(
            backgroundColor: myColors.brandColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100)
            ),
            onPressed: () async {
              if ( formKey.currentState!.validate() && isUsernameAvailable && !isVerifyingUsername ) {
                var data = widget.data;
                data['username'] = usernameController.text;
                data['password'] = passwordController.text;
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => SetupAvatar( data: data),
                //   ),
                // );
              }
              //Navigator.pushNamed(context, '/sign-in');
            },
            label: Text(LanguageNotifier.of(context)!.translate('continue')),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}
