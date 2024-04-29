import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:radius_app/pages/avatars.dart';
import 'package:radius_app/pages/block_list.dart';
import 'package:radius_app/pages/change_password.dart';
import 'package:radius_app/pages/get_started.dart';
import 'package:radius_app/pages/menu.dart';
import 'package:radius_app/pages/home.dart';
import 'package:radius_app/pages/loading.dart';
import 'package:radius_app/pages/messages.dart';
import 'package:radius_app/pages/permissions.dart';
import 'package:radius_app/pages/privacy_policy.dart';
import 'package:radius_app/pages/settings.dart';
import 'package:radius_app/pages/setup_avatar.dart';
import 'package:radius_app/pages/sign_in.dart';
import 'package:radius_app/pages/forgot_password.dart';
import 'package:radius_app/pages/sign_up.dart';
import 'package:radius_app/pages/toc.dart';
import 'package:radius_app/services/chatManager.dart';
import 'package:radius_app/services/languageManager.dart';
import 'package:radius_app/services/loaderNotifer.dart';
import 'package:radius_app/services/locationManager.dart';
import 'package:radius_app/services/permissionManager.dart';
import 'package:radius_app/services/storageManager.dart';
import 'package:radius_app/services/themeManager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:radius_app/services/userManager.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:radius_app/singleton/socket_singleton.dart';
import 'package:rxdart/rxdart.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// TODO: Add stream controller
// used to pass messages from event handler to the UI
final _messageStreamController = BehaviorSubject<RemoteMessage>();
// TODO: Define the background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp( options: DefaultFirebaseOptions.currentPlatform, );
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification?.title}');
  debugPrint('Message notification: ${message.notification?.body}');
}

Future<void> main() async{
  // I THINK THIS CAN WORK FOR APP (ON ANDROID) TO CALL DE-ATTACH
  WidgetsFlutterBinding.ensureInitialized();
  // Load env file
  await dotenv.load(fileName: ".env");
  // Init Firebase DB
  try{
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }catch( e ){
    debugPrint(e.toString());
  }

  // TODO: Request permission
  // TODO: Register with FCM
  // TODO: Set up foreground message handler
  FirebaseMessaging.onMessageOpenedApp.listen(( RemoteMessage message ) async {
    debugPrint('ON APP OPENED FROM NOTIFICATION');
    await Navigator.pushAndRemoveUntil(
        navigatorKey.currentState!.context,
        MaterialPageRoute(builder: (BuildContext context) => Messages()),
        ModalRoute.withName('/home'),
    );
  });
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Handling a foreground message: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    debugPrint('Message notification: ${message.notification?.title}');
    debugPrint('Message notification: ${message.notification?.body}');
    _messageStreamController.sink.add(message);
  });
  // TODO: Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Run App
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>( create: (context) => ThemeNotifier()),
        ChangeNotifierProvider<PermissionManager>( create: (context) => PermissionManager()),
        ChangeNotifierProvider<ChatManager>( create: (context) => ChatManager()),
        ChangeNotifierProvider<LocationManager>( create: (context) => LocationManager()),
        ChangeNotifierProvider<LoaderNotifier>( create: (context) => LoaderNotifier()),
      ],
      child: MyApp(),
    ),
  );
}


class MyApp extends StatefulWidget with ChangeNotifier {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale _locale = const Locale.fromSubtags(languageCode: 'en');
  final LanguageNotifier languageNotifier = LanguageNotifier();
  String _lastMessage = "";
  final SocketSingleton ss = SocketSingleton();
  Timer? _timer;
  var currentSeconds = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    getSelectedLangCode();
    _messageStreamController.listen((message) {
      setState(() {
        if (message.notification != null) {
          _lastMessage = 'Received a notification message:'
              '\nTitle=${message.notification?.title},'
              '\nBody=${message.notification?.body},'
              '\nData=${message.data}';
        } else {
          _lastMessage = 'Received a data message: ${message.data}';
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    final isLoggedIn = await UserManager().isLoggedIn();
    String uid = '';
    if( isLoggedIn ){
      final user = await StorageManager.getUser();
      uid = user['uid'];
    }

    switch (state) {
      case AppLifecycleState.resumed:
        // StorageManager.saveData('location-enabled', false);
        // StorageManager.saveData('location-denied', false);
        // if(mounted){
        //   Provider.of<LocationManager>(context, listen: false).setLocationPermissionStatus( false );
        //   Provider.of<LocationManager>(context, listen: false).denyPermissionStatus( false );
        // }
        debugPrint('MAIN -> APP is resumed');
        _timer?.cancel();
        if( uid.isNotEmpty ){
          if( ss.socket.connected ){
            ss.socket.emit('set-user-status', { "uid" : uid, "status" : true });
          }else{
            ss.init( uid );
            UserManager().updateUserAvailability( uid, true );
          }
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _timer?.cancel();
        _timer= Timer.periodic(const Duration(seconds: 1), (timer) async {
          // IF USER IS BACKGROUND FOR 2 MINUTES
          if (timer.tick >= 60 * 2){
            _timer?.cancel();
            StorageManager.saveData('location-enabled', false);
            StorageManager.saveData('location-denied', false);
            StorageManager.saveData('privacy-disabled', false);
            if( ss.socket.connected ){
              ss.socket.emit('custom-disconnect', { "uid" : uid });
              ss.socket.clearListeners();
              ss.socket.disconnect();
              ss.socket.dispose();
            }
          }
        });
        break;
      // CALLS WHEN APP (CLOSED)
      case AppLifecycleState.detached:
        StorageManager.saveData('location-enabled', false);
        StorageManager.saveData('location-denied', false);
        StorageManager.saveData('privacy-disabled', false);
        debugPrint('App detached in Main with following: \nSocked Status : ${ss.socket.connected} \nUser ID : $uid \nExecute Condition: ${(ss.socket.connected && uid.isNotEmpty).toString()}');
        _timer?.cancel();
        if( ss.socket.connected && uid.isNotEmpty ){
          ss.socket.emit('custom-disconnect', { "uid" : uid });
          ss.socket.clearListeners();
          ss.socket.disconnect();
          ss.socket.dispose();
          debugPrint('Clearing Chats');
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  void getSelectedLangCode() async {
    String code =  await languageNotifier.getLocale();
    _locale = Locale.fromSubtags(languageCode: code);
  }

  void setLocale(){
    String lang = 'en';
    if( _locale.languageCode == 'en' ){
      lang = 'ar';
    }else{
      lang = 'en';
    }
    _locale = Locale.fromSubtags(languageCode: lang);
    setState(() { languageNotifier.setLocale(lang); });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return Consumer5<ThemeNotifier, PermissionManager, ChatManager, LocationManager, LoaderNotifier>(
        builder: (context, theme, permission, chats, location, loader, _)  => MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: const [
              LanguageNotifier.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale("ar", "AE"),
              Locale("en", "US"),
            ],
            locale: _locale,
            // Return a locale which will be used by app
            // localeListResolutionCallback: (locale, supportedLocales){
            //   // Check if current device locale is supported
            //   for( var supportedLocalesLang in  supportedLocales ){
            //     if( supportedLocalesLang.languageCode == locale?.languageCode &&
            //         supportedLocalesLang.countryCode == locale?.countryCode){
            //         return supportedLocalesLang;
            //     }
            //   }
            //   // If device not supported with locale
            //   return supportedLocales.first;
            // },
            theme: theme.getTheme(),
            //themeMode: ThemeMode.dark,
            initialRoute: '/',
            // routes: {
            //   // '/' : (context) => Loading(),
            //   // '/get-started' : (context) => GetStarted(),
            //   // '/sign-in' : (context) => SignIn(),
            //   // '/sign-up' : (context) => SignUp(),
            //   // //'/otp' : (context) => OTPScreen(),
            //   // //'/setup_profile' : (context) => SetupProfile(),
            //   // '/avatars' : (context) => Avatars(),
            //   // '/forgot-password': (context) => ForgotPassword(),
            //   // '/permissions' : (context) => CustomPermissions(),
            //   // '/home' : (context) => Home(),
            //   // '/messages' : (context) => Messages(),
            //   // '/menu' : (context) => Menu(theme :theme, onSetLocale : setLocale ),
            //   // '/block-list' : (context) => BlockList(),
            //   // //'/chat' : (context) => Chat(),
            //   // '/toc'  : (context) => const Toc(),
            // },
            onGenerateRoute: (settings) {
              switch ( settings.name ){
                case '/' :
                  return PageTransition( child: Loading(), type: PageTransitionType.theme, settings: settings, );
                case '/get-started' :
                  return PageTransition( child: GetStarted(), type: PageTransitionType.theme, settings: settings, );
                case '/sign-in' :
                  return PageTransition( child: SignIn(), type: PageTransitionType.theme, settings: settings, );
                case '/sign-up' :
                  return PageTransition( child: SignUp(), type: PageTransitionType.theme, settings: settings, );
                case '/setup-avatar' :
                  return PageTransition( child: SetupAvatar(), type: PageTransitionType.theme, settings: settings, );
                case '/avatars' :
                  return PageTransition( child: Avatars(), type: PageTransitionType.theme, settings: settings, );
                case '/forgot-password' :
                  return PageTransition( child: ForgotPassword(), type: PageTransitionType.theme, settings: settings, );
                case '/permissions' :
                  return PageTransition( child: CustomPermissions(), type: PageTransitionType.theme, settings: settings, );
                case '/home' :
                  return PageTransition( child: Home(), type: PageTransitionType.leftToRight, settings: settings, );
                case '/messages' :
                  return PageTransition( child: Messages(), type: PageTransitionType.leftToRight, settings: settings );
                case '/menu' :
                  return PageTransition( child: Menu(theme :theme, onSetLocale : setLocale, ), type: PageTransitionType.rightToLeft, settings: settings, );
                case '/block-list' :
                  return PageTransition( child: BlockList(), type: PageTransitionType.theme, settings: settings, );
                case '/toc' :
                  return PageTransition( child: const Toc(), type: PageTransitionType.theme, settings: settings, );
                case '/settings' :
                  return PageTransition( child: const Settings(), type: PageTransitionType.theme, settings: settings, );
                case '/change-password' :
                  return PageTransition( child: const ChangePassword(), type: PageTransitionType.theme, settings: settings, );
                case '/privacy-policy' :
                  return PageTransition( child: const PrivacyPolicy(), type: PageTransitionType.theme, settings: settings, );
              }
              return null;
            },
          )
    );
  }
}