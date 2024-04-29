import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/pages/reset_password.dart';
import 'package:radius_app/pages/setup_profile.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/mailService.dart';

class OTPScreen extends StatefulWidget {
  final dynamic data;
  const OTPScreen({Key? key, required this.data}) : super(key: key);

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  MailerService mailer = MailerService();
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String email = '';
  String action = '';

  final int _otpLength = 6; // number of OTP digits
  String otp = '123456';
  bool isOtpVerified = false;
  bool showSpinner = false;

  @override
  void initState() {
    super.initState();
    email = widget.data['email'] as String;
    action = widget.data['action'] as String;
    sendEmailVerification();
  }

  Future<void> sendEmailVerification() async {
    try{
      otp = (100000 + Random().nextInt(900000)).toString();
      showSpinner = true;
      setState(() {});
      debugPrint( 'OTP GENERATED : $otp');
      final response = await mailer.sendEmail(email, 'OTP Verification', 'Your OTP is $otp');
      if( response['status'] && context.mounted ){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $email'),
          ),
        );
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error']),
          ),
        );
      }
      showSpinner = false;
      setState(() {});
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return WillPopScope(
        onWillPop: ()  async { return false; },
        child: Consumer<ThemeNotifier>(
          builder: (context, theme, _) => Scaffold(
            backgroundColor: myColors.appSecBgColor,
            appBar: AppBar(
              backgroundColor: myColors.appSecBgColor,
              title: Text(LanguageNotifier.of(context)!.translate('otp_verification'), style: TextStyle(color: myColors.appSecTextColor),),
              centerTitle: true,
              leading: IconButton(
                color: myColors.appSecTextColor,
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Stack(
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: Image.asset((theme.isLightMode) ? 'assets/videos/2-light.gif' : 'assets/videos/2-dark.gif', color: Colors.white.withOpacity(0.8), colorBlendMode: BlendMode.modulate,),
                    ),
                  ),
                ),
                Form(
                  key: formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: [
                            Expanded(child: Text(LanguageNotifier.of(context)!.translate('otp_verification'), style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500),),),
                            ( showSpinner ) ? Row(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator( strokeWidth: 3,),
                                ),
                                const SizedBox(width: 10),
                                Text(LanguageNotifier.of(context)!.translate('sending_otp'))
                              ],
                            ) : Container(),
                          ],
                        ),
                        const SizedBox(height: 20.0,),
                        Text(
                          '${LanguageNotifier.of(context)!.translate('otp_verification_hint')}$email',
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                        const SizedBox(height: 40.0,),
                        TextFormField(
                          controller: _otpController,
                          maxLength: _otpLength,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                            labelText: LanguageNotifier.of(context)!.translate('otp'),
                            hintText: LanguageNotifier.of(context)!.translate('otp_hint'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: ( value) {
                            if (value!.isEmpty) {
                              return LanguageNotifier.of(context)!.translate('error_otp_required');
                            } else if (value.length < _otpLength) {
                              return LanguageNotifier.of(context)!.translate('error_otp_length');
                            }else if (value != otp) {
                              return LanguageNotifier.of(context)!.translate('error_otp_invalid');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: MediaQuery.of(context).size.width*0.9,
                          child: FilledButton(
                            onPressed: () {
                              if ( formKey.currentState!.validate() ) {
                                if( action == 'signup' ){
                                  Navigator.pushReplacement(
                                      context, MaterialPageRoute(
                                    builder: (context) => SetupProfile( data: widget.data ),
                                  )
                                  );
                                }else if( action == 'forget-password' ){
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResetPassword( data: widget.data ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(LanguageNotifier.of(context)!.translate('continue'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(LanguageNotifier.of(context)!.translate('no_code')),
                            const SizedBox(width: 5.0,),
                            InkWell(
                              onTap: () { sendEmailVerification(); },
                              child: Text(LanguageNotifier.of(context)!.translate('resend_code'), style: const TextStyle(color: Color(0xFFC835C1), fontWeight: FontWeight.w700),),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
