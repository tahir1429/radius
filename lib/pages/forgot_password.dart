import 'package:flutter/material.dart';
import 'package:radius_app/pages/otp_screen.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/userManager.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({Key? key}) : super(key: key);

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  UserManager userManager = UserManager();
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isSpinning = false;
  bool isEmailExist = true;

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Scaffold(
      backgroundColor: myColors.appSecBgColor,
      appBar: AppBar(
        backgroundColor: myColors.appSecBgColor,
        title: Text(LanguageNotifier.of(context)!.translate('forgot_password'), style: TextStyle(color: myColors.appSecTextColor),),
        centerTitle: true,
        leading: IconButton(
          color: myColors.appSecTextColor,
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0.2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 20.0,),
                Text(
                  LanguageNotifier.of(context)!.translate('forgot_password_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.0, color: Color(0xFF8F9BB3), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20.0,),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 16.0, height: 1.0),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: myColors.appSecBgColor,
                    labelText: LanguageNotifier.of(context)!.translate('email'),
                    hintText: LanguageNotifier.of(context)!.translate('email_hint'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: ( value) {
                    if (value!.isEmpty) {
                      return LanguageNotifier.of(context)!.translate('error_email_required');
                    }
                    else if ( !value.contains('@') || !value.contains('.') ) {
                      return LanguageNotifier.of(context)!.translate('error_email_invalid');
                    }
                    else if ( !isEmailExist ) {
                      return LanguageNotifier.of(context)!.translate('error_email_not_exist');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0,),
                SizedBox(
                  width: MediaQuery.of(context).size.width*0.9,
                  child: FilledButton(
                    onPressed: () async {
                      isEmailExist = true;
                      if ( formKey.currentState!.validate() ) {
                        setState(() => isSpinning = true);
                        final response = await userManager.isEmailTaken(emailController.text.toLowerCase() );
                        if( response['status'] && response['exist'] && context.mounted ){
                          var data = {
                            "email" : emailController.text.toLowerCase(),
                            "action": "forget-password"
                          };
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OTPScreen( data: data),
                            ),
                          );
                        }else{
                          isEmailExist = false;
                        }
                        setState(() => isSpinning = false);
                      }
                    },
                    child: ( isSpinning ) ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white,),) : Text(LanguageNotifier.of(context)!.translate('send'), style: const TextStyle( fontSize: 16.0, fontWeight: FontWeight.w700),)
                  ),
                ),
                const SizedBox(height: 20.0,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(LanguageNotifier.of(context)!.translate('no_code')),
                    const SizedBox(width: 5.0,),
                    InkWell(
                      onTap: () {},
                      child: Text(LanguageNotifier.of(context)!.translate('resend_code'), style: const TextStyle(color: Color(0xFFC835C1), fontWeight: FontWeight.w700),),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
