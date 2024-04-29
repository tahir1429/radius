import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/pages/sign_up_step_two.dart';
import 'package:radius_app/services/userManager.dart';
import 'package:intl/intl.dart';

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  UserManager userManager = UserManager();
  final formKey = GlobalKey<FormState>();
  TextEditingController fistNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController dobController = TextEditingController(text: '');
  bool isEmailAvailable = true;
  bool isVerifyingEmail = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    fistNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime today = DateTime.now();
    int lastDateYear = today.year - 16;

    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime( lastDateYear, today.month, today.day ),
        firstDate: DateTime(1950, 8),
        lastDate: DateTime(lastDateYear, today.month, today.day),
        initialEntryMode: DatePickerEntryMode.calendarOnly
    );
    if ( picked != null ) {
      setState(() {
        String date = DateFormat('dd/MM/yyyy').format( picked );
        dobController.text = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return WillPopScope(
      onWillPop: () async { Navigator.pop(context); return true; },
      child: Consumer<ThemeNotifier>(
      builder: (context, theme, _) => Scaffold(
        backgroundColor: myColors.appSecBgColor,
        appBar: AppBar(
          backgroundColor: myColors.appSecBgColor,
          title: Text(LanguageNotifier.of(context)!.translate('sign_up'), style: TextStyle(color: myColors.appSecTextColor),),
          centerTitle: true,
          leading: IconButton(
            color: myColors.appSecTextColor,
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0.2,
        ),
        body: Stack(
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Image.asset( (theme.isLightMode) ? 'assets/videos/1-light.gif' : 'assets/videos/1-dark.gif', color: Colors.white.withOpacity(0.8), colorBlendMode: BlendMode.modulate,),
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  controller: fistNameController,
                                  keyboardType: TextInputType.name,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                                    labelText: LanguageNotifier.of(context)!.translate('fistName'),
                                    isDense: true,
                                    hintText: LanguageNotifier.of(context)!.translate('fistName'),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter(RegExp(r'[A-Za-z]'), allow: true)
                                  ],
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return LanguageNotifier.of(context)!.translate('error_firstName_required');
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10,),
                              Expanded(
                                child: TextFormField(
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  controller: lastNameController,
                                  keyboardType: TextInputType.name,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                                    labelText: LanguageNotifier.of(context)!.translate('lastName'),
                                    isDense: true,
                                    hintText: LanguageNotifier.of(context)!.translate('lastName'),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter(RegExp(r'[A-Za-z]'), allow: true)
                                  ],
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return LanguageNotifier.of(context)!.translate('error_lastName_required');
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20,),
                          TextFormField(
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                              labelText: LanguageNotifier.of(context)!.translate('email'),
                              isDense: true,
                              hintText: LanguageNotifier.of(context)!.translate('email_hint'),
                            ),
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
                          ( isEmailAvailable ) ? Container() :  (emailController.text.isNotEmpty) ? Container( padding: const EdgeInsets.only(top: 10), child: Text(LanguageNotifier.of(context)!.translate('error_email_taken') , style: const TextStyle(color: Colors.red),),) : Container(),
                          const SizedBox(height: 20,),
                          TextFormField(
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                              border: const OutlineInputBorder(),
                              isDense: true,
                              //prefixText: '+996',
                              labelText: LanguageNotifier.of(context)!.translate('phone_number'),
                              hintText: LanguageNotifier.of(context)!.translate('phone_number_hint'),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter(RegExp(r'[\d+]'), allow: true)
                            ],
                            validator: (value) {
                              if (value!.isEmpty) {
                                return LanguageNotifier.of(context)!.translate('error_phone_required');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20,),
                          // (
                          //   autovalidateMode: AutovalidateMode.onUserInteraction,
                          //   controller: dobController,
                          //   keyboardType: TextInputType.none,
                          //   decoration: InputDecoration(
                          //     filled: true,
                          //     fillColor: (theme.isLightMode) ? Colors.white : Colors.black,
                          //     border: const OutlineInputBorder(),
                          //     isDense: true,
                          //     labelText: LanguageNotifier.of(context)!.translate('dob'),
                          //     hintText: '00/00/0000',
                          //   ),
                          //   validator: (value) {
                          //     if (value == null || value.isEmpty) {
                          //       return null;
                          //     }
                          //     // if (value!.isEmpty) {
                          //     //   return LanguageNotifier.of(context)!.translate('error_dob_required');
                          //     // }
                          //     return null;
                          //   },
                          //   onTap: () => _selectDate( context ),
                          // ),TextFormField
                          // const SizedBox(height: 20,),
                          SizedBox(
                            width: MediaQuery.of(context).size.width*0.9,
                            child: FilledButton(
                              child: ( isVerifyingEmail ) ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,),) : Text(LanguageNotifier.of(context)!.translate('continue'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
                              onPressed: () async{
                                isEmailAvailable = true;
                                if ( formKey.currentState!.validate() ) {
                                  setState(() => isVerifyingEmail = true);
                                  final response = await userManager.isEmailTaken(emailController.text.toLowerCase());
                                  if( response['status'] ){
                                    isEmailAvailable = !response['exist'];
                                  }else{
                                    isEmailAvailable = false;
                                  }
                                  setState(() => isVerifyingEmail = false);
                                  if( isEmailAvailable && context.mounted){
                                    var data = {
                                      "email" : emailController.text.toLowerCase(),
                                      "phone" : phoneController.text,
                                      "fname" : fistNameController.text,
                                      "lname" : lastNameController.text,
                                      "dob"   : dobController.text,
                                    };
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SignUpStepTwo( data: data),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 20.0,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(LanguageNotifier.of(context)!.translate('have_account')),
                              const SizedBox(width: 5.0,),
                              InkWell(
                                onTap: () => Navigator.pushNamed(context, '/sign-in'),
                                child: Text(LanguageNotifier.of(context)!.translate('sign_in'), style: const TextStyle(color: Color(0xFFC835C1), fontWeight: FontWeight.w700),),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
