import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/mailService.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/pages/setup_avatar.dart';

class SignUpStepTwo extends StatefulWidget {
  final dynamic data;
  const SignUpStepTwo({Key? key, required this.data}) : super(key: key);

  @override
  State<SignUpStepTwo> createState() => _SignUpStepTwoState();
}

class _SignUpStepTwoState extends State<SignUpStepTwo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  UserManager userManager = UserManager();
  MailerService mailer = MailerService();
  final TextEditingController _otpController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController cfnPasswordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final int _otpLength = 6;
  String otp = '123456';
  bool isOtpVerified = false;
  bool isSendingOTP = false;
  bool showSpinner = false;
  bool isPasswordVisible = false;

  String email = '';

  @override
  void initState() {
    super.initState();
    email = widget.data['email'] as String;
    _otpController.addListener(_verifyOtp);
    sendEmailVerification();
  }

  @override
  void dispose(){
    _controller.dispose();
    _otpController.dispose();
    passwordController.dispose();
    cfnPasswordController.dispose();
    super.dispose();
  }

  Future<void> sendEmailVerification() async {
    try{
      otp = (100000 + Random().nextInt(900000)).toString();
      isSendingOTP = true;
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
      isSendingOTP = false;
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

  void _verifyOtp(){
    setState(() { });
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return WillPopScope(
      onWillPop: ()  async { return false; },
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) => ( !showSpinner ) ? Scaffold(
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
              SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: [
                            Expanded(child: Text(LanguageNotifier.of(context)!.translate('otp_verification'), style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500),),),
                            ( isSendingOTP ) ? Row(
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
                        const SizedBox(height: 20.0,),
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
                          onChanged: ( text ) => _verifyOtp(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(LanguageNotifier.of(context)!.translate('no_code')),
                            const SizedBox(width: 5.0,),
                            InkWell(
                              onTap: () { sendEmailVerification(); },
                              child: Text(LanguageNotifier.of(context)!.translate('resend_code'), style: const TextStyle(color: Color(0xFFC835C1), fontWeight: FontWeight.w700),),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        ( _otpController.text == otp ) ? Text(LanguageNotifier.of(context)!.translate('setup_password'), style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500),) : Container(),
                        SizedBox(height: ( _otpController.text == otp ) ? 20 : 0,),
                        ( _otpController.text == otp ) ? TextFormField(
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
                        ) : Container(),
                        SizedBox(height: ( _otpController.text == otp ) ? 20 : 0,),
                        ( _otpController.text == otp ) ? TextFormField(
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
                        ) : Container(),
                        SizedBox(height: ( _otpController.text == otp ) ? 20 : 0,),
                        ( _otpController.text == otp ) ? SizedBox(
                          width: MediaQuery.of(context).size.width*0.9,
                          child: FilledButton(
                            onPressed: () async {
                              if ( formKey.currentState!.validate() ) {
                                dynamic data = widget.data;
                                data['password'] = passwordController.text;


                                setState(() => showSpinner = true);

                                final account = await userManager.register( data, null );
                                if( account['status'] && context.mounted ) {
                                  StorageManager.saveUser( account['user'], jwtToken: account['token'] );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SetupAvatar(),
                                    ),
                                  );
                                }else{
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(account['message']),)
                                  );
                                }
                                setState(() => showSpinner = false);
                              }
                            },
                            child: Text(LanguageNotifier.of(context)!.translate('continue'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
                          ),
                        ) : Container(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ) : Scaffold(
          backgroundColor: myColors.appSecBgColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 100,
                    height: 100,
                    repeat: ImageRepeat.noRepeat,
                    alignment: Alignment.center,
                    color: ( theme.isLightMode ) ? Colors.black : Colors.white,
                  ),
                ),
                const SizedBox(height: 20,),
                Text(LanguageNotifier.of(context)!.translate('creating_account'), style: const TextStyle(fontSize: 18),)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
