import 'package:flutter/material.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:page_transition/page_transition.dart';
import 'package:radius_app/pages/sign_in.dart';

class GetStarted extends StatefulWidget {
  const GetStarted({Key? key}) : super(key: key);

  @override
  State<GetStarted> createState() => _GetStartedState();
}

class _GetStartedState extends State<GetStarted> {
  int _currentStep = 0;
  var strings = ['one', 'two', 'three', 'four'];

  getDotColor( step ){
    if( _currentStep == step ){
      return const Color(0xFFC835C1);
    }
    return const Color(0xFFD9D9D9);
  }
  double getDotWidth( step ){
    if( _currentStep == step ){
      return 20.0;
    }
    return 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final MyColors myColors = Theme.of(context).extension<MyColors>()!;

    return Scaffold(
      backgroundColor: myColors.appSecBgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'assets/logo-black.png',
                  width: MediaQuery.of(context).size.width*0.7,
                  repeat: ImageRepeat.noRepeat,
                  alignment: Alignment.center,
                  color: myColors.appSecTextColor,
                ),
                const SizedBox(height: 30.0,),
                // Image.asset(
                //   'assets/main.png',
                //   width: 200,
                //   scale: 0.5,
                // ),
                const SizedBox(height: 30.0,),
                Text(
                  LanguageNotifier.of(context)!.translate('slider_text_1'),
                  style: const TextStyle(
                    color: Color(0xFFC835C1),
                    fontWeight: FontWeight.w700,
                    fontSize: 16.0
                  ),
                ),
                const SizedBox(height: 20.0,),
                Text(
                  LanguageNotifier.of(context)!.translate('slider_text_2'),
                  style: const TextStyle(
                      color: Color(0xFFC835C1),
                      fontWeight: FontWeight.w700,
                      fontSize: 16.0
                  ),
                ),
                const SizedBox(height: 50.0,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    InkWell(
                      child: Container(
                        width: getDotWidth(0),
                        height: 10,
                        decoration: BoxDecoration(
                            color: getDotColor(0),
                            border: Border.all( color: getDotColor(0)),
                            borderRadius: BorderRadius.circular(100)
                        ),
                      ),
                      onTap: (){
                        setState(() { _currentStep = 0; });
                      },
                    ),
                    const SizedBox(width: 10.0,),
                    InkWell(
                      child: Container(
                        width: getDotWidth(1),
                        height: 10,
                        decoration: BoxDecoration(
                            color: getDotColor(1),
                            border: Border.all( color: getDotColor(1)),
                            borderRadius: BorderRadius.circular(100)
                        ),
                      ),
                      onTap: (){
                        setState(() { _currentStep = 1; });
                      },
                    ),
                    const SizedBox(width: 10.0,),
                    InkWell(
                      child: Container(
                        width: getDotWidth(2),
                        height: 10,
                        decoration: BoxDecoration(
                            color: getDotColor(2),
                            border: Border.all( color: getDotColor(2)),
                            borderRadius: BorderRadius.circular(100)
                        ),
                      ),
                      onTap: (){
                        setState(() { _currentStep = 2; });
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.only(bottom: 20),
        width: MediaQuery.of(context).size.width*0.9,
        child: FloatingActionButton.extended(
          backgroundColor: myColors.brandColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)
          ),
          onPressed: () => {
            Navigator.pushNamed(context, '/sign-in')
            // Navigator.pushReplacement(context, PageTransition(
            //     type: PageTransitionType.bottomToTop,
            //     child: SignIn(),
            //     duration: const Duration(milliseconds: 500)
            // ))
          },
          label: Text(LanguageNotifier.of(context)!.translate('continue'),),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
