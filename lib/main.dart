import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:device_preview/device_preview.dart' hide DeviceOrientation;
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:state_persistence/state_persistence.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:rxdart/subjects.dart';
import 'package:minsk8/import.dart';

// TODO: https://github.com/FirebaseExtended/flutterfire/tree/master/packages/firebase_analytics
// TODO: на всех экранах, где не нужна клавиатура, вставить Scaffold.resizeToAvoidBottomInset: false,
// TODO: поменять все print(object) на debugPrint(String) ?
// TODO: timeout для подписок GraphQL, смотри примеры
// TODO: Image.asset автоматически показывает версию файла в зависимости от плотности пикселей устройства: - images/dash.png или - images/2x/dash.png
// TODO: Убрать лишние Material и InkWell
// TODO: выставить textColor для кнопок, чтобы получить цветной InkWell (см. еще на MaterialButton.splashColor)
// TODO: auto_animated
// TODO: профилирование анимации debugProfileBuildsEnabled: true,
// TODO: проверить везде fit: StackFit.expand,
// TODO: [MVP] не работает системная кнопка 'BACK'?
// TODO: бейджики для активных участников
// TODO: выходящий за пределы экрана InkWell для системной кнопки Close - OverflowBox
// TODO: автоматизация локализации https://medium.com/in-the-pocket-insights/localising-flutter-applications-and-automating-the-localisation-process-752a26fe179c
// TODO: сторонний вариант локализации https://github.com/aissat/easy_localization
// TODO: пока загружается аватарка - показывать ожидание
// TODO: добавить google-services-info.plist https://support.google.com/firebase/answer/7015592?hl=ru
// TODO: flutter telegram-auth
// TODO: закруглить кнопки и диалоги, как в https://console.firebase.google.com
// TODO: [MVP] Step-by-step guide to Android code signing and code signing https://blog.codemagic.io/the-simple-guide-to-android-code-signing/

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotificationModel>();
final selectNotificationSubject = BehaviorSubject<String>();
NotificationAppLaunchDetails notificationAppLaunchDetails;

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    print(details);
    // if (isInDebugMode) {
    //   // In development mode, simply print to console.
    //   FlutterError.dumpErrorToConsole(details);
    // } else {
    //   // In production mode, report to the application zone to report to
    //   // Sentry.
    //   Zone.current.handleUncaughtError(details.exception, details.stack);
    // }
  };
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    // Note: permissions aren't requested here just to demonstrate that can be done later using the `requestPermissions()` method
    // of the `IOSFlutterLocalNotificationsPlugin` class
    var initializationSettingsIOS = IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        onDidReceiveLocalNotification:
            (int id, String title, String body, String payload) async {
          didReceiveLocalNotificationSubject.add(ReceivedNotificationModel(
              id: id, title: title, body: body, payload: payload));
        });
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (String payload) async {
      if (payload != null) {
        debugPrint('notification payload: ' + payload);
      }
      selectNotificationSubject.add(payload);
    });
    // TODO: locale autodetect
    // await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('ru_RU', null);
    // runApp(
    //   DevicePreview(
    //     enabled: isInDebugMode,
    //     builder: (BuildContext context) => App(),
    //   ),
    // );
    runApp(AuthCheck());
  }, (error, stackTrace) {
    print(error);
    // Whenever an error occurs, call the `_reportError` function. This sends
    // Dart errors to the dev console or Sentry depending on the environment.
    // _reportError(error, stackTrace);
  });
}

// Future<void> _reportError(dynamic error, dynamic stackTrace) async {
//   // Print the exception to the console.
//   print('Caught error: $error');
//   if (isInDebugMode) {
//     // Print the full stacktrace in debug mode.
//     print(stackTrace);
//     return;
//   } else {
//     // Send the Exception and Stacktrace to Sentry in Production mode.
//     _sentry.captureException(
//       exception: error,
//       stackTrace: stackTrace,
//     );
//   }
// }

// TODO: Обернуть требуемые экраны в SafeArea (проверить на iPhone X)

// TODO: переименовать в appData
PersistedData appState;
final localDeletedUnitIds = <String>{}; // ie Set()

class App extends StatelessWidget {
  App({this.authData});

  final AuthData authData;

  static final analytics = FirebaseAnalytics();
  static final observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    // print('App build');
    Widget result = CommonMaterialApp(
      navigatorObservers: <NavigatorObserver>[observer],
      builder: (BuildContext context, Widget child) {
        // if (isInDebugMode) {
        //   child = DevicePreview.appBuilder(context, child);
        // }
        App.analytics.setCurrentScreen(screenName: '/app');
        final client = GraphQLProvider.of(context).value;
        HomeShowcase.dataPool = kAllKinds
            .map((EnumModel kind) => ShowcaseData(client, kind.value))
            .toList();
        HomeUnderway.dataPool = UnderwayValue.values
            .map((value) => UnderwayData(client, value))
            .toList();
        LedgerScreen.sourceList = LedgerData(client);
        return PersistedStateBuilder(
          builder:
              (BuildContext context, AsyncSnapshot<PersistedData> snapshot) {
            if (!snapshot.hasData) {
              return Material(
                child: Center(
                  child: Text('Loading state...'),
                ),
              );
            }
            appState = PersistedAppState.of(context);
            return FutureBuilder<bool>(
                future: authData.isLogin
                    ? _upsertMember(client)
                    : Future.value(true),
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Material(
                      child: Center(
                        child: Text('Update member...'),
                      ),
                    );
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      !snapshot.data) {
                    // TODO: [MVP] чтобы попробовать ещё раз - setState()
                    return Material(
                      child: Center(
                        child: Text('Кажется, что-то пошло не так?'),
                      ),
                    );
                  }
                  return Query(
                    options: QueryOptions(
                      documentNode: Queries.getProfile,
                      variables: {'member_id': appState['memberId']},
                      fetchPolicy: FetchPolicy.noCache,
                    ),
                    // Just like in apollo refetch() could be used to manually trigger a refetch
                    // while fetchMore() can be used for pagination purpose
                    builder: (QueryResult result,
                        {VoidCallback refetch, FetchMore fetchMore}) {
                      if (result.hasException) {
                        debugPrint(
                            getOperationExceptionToString(result.exception));
                        return Material(
                          child: InkWell(
                            onTap: refetch,
                            child: Center(
                              child: Text('Кажется, что-то пошло не так?'),
                            ),
                          ),
                        );
                      }
                      if (result.loading) {
                        return Material(
                          child: Center(
                            child: Text('Loading profile...'),
                          ),
                        );
                      }
                      return MultiProvider(
                        providers: <SingleChildWidget>[
                          ChangeNotifierProvider<ProfileModel>(
                              create: (_) => ProfileModel.fromJson(
                                  result.data['profile'])),
                          ChangeNotifierProvider<MyWishesModel>(
                              create: (_) =>
                                  MyWishesModel.fromJson(result.data)),
                          ChangeNotifierProvider<DistanceModel>(
                              create: (_) => DistanceModel()),
                          ChangeNotifierProvider<MyUnitMapModel>(
                              create: (_) => MyUnitMapModel()),
                          ChangeNotifierProvider<AppBarModel>(
                              create: (_) => AppBarModel()),
                        ],
                        child: MediaQueryWrap(child),
                      );
                    },
                  );
                });
          },
        );
      },
      home: HomeScreen(),
      initialRoute: kInitialRouteName,
      routes: <String, WidgetBuilder>{
        '/_animation': (_) => AnimationScreen(),
        '/_custom_dialog': (_) => CustomDialogScreen(),
        '/_image_capture': (_) => ImageCaptureScreen(),
        '/_image_pinch': (_) => ImagePinchScreen(),
        '/_load_data': (_) => LoadDataScreen(),
        '/_nested_scroll_view': (_) => NestedScrollViewScreen(),
        '/_notifiaction': (_) => NotificationScreen(),
        // ****
        '/about': (_) => ContentScreen('about.md', title: 'О проекте'),
        '/faq': (_) => ContentScreen('faq.md', title: 'Вопросы и ответы'),
        '/forgot_password': (_) => ForgotPasswordScreen(),
        '/how_it_works': (_) =>
            ContentScreen('how_it_works.md', title: 'Как это работает?'),
        '/ledger': (_) => LedgerScreen(),
        '/make_it_together': (_) =>
            ContentScreen('make_it_together.md', title: 'Сделаем это вместе!'),
        '/search': (_) => SearchScreen(),
        '/start': (_) => StartScreen(),
        '/useful_tips': (_) =>
            ContentScreen('useful_tips.md', title: 'Полезные советы'),
      },
      onGenerateRoute: (RouteSettings settings) {
        final fullScreenDialogRoutes = <String, WidgetBuilder>{
          '/add_unit': (BuildContext context) =>
              AddUnitScreen(ModalRoute.of(context).settings.arguments),
          '/edit_unit': (BuildContext context) =>
              EditUnitScreen(ModalRoute.of(context).settings.arguments),
          '/feedback': (_) => FeedbackScreen(),
          '/how_to_pay': (_) => HowToPayScreen(),
          '/invite': (_) => InviteScreen(),
          '/kinds': (BuildContext context) =>
              KindsScreen(ModalRoute.of(context).settings.arguments),
          // '/login': (_) => LoginScreen(),
          '/my_unit_map': (_) => MyUnitMapScreen(),
          '/payment': (_) => PaymentScreen(),
          '/settings': (_) => SettingsScreen(),
          '/showcase_map': (_) => ShowcaseMapScreen(),
          '/sign_up': (_) => SignUpScreen(),
          '/start_map': (_) => StartMapScreen(),
          '/unit': (BuildContext context) =>
              UnitScreen(ModalRoute.of(context).settings.arguments),
          '/unit_map': (BuildContext context) =>
              UnitMapScreen(ModalRoute.of(context).settings.arguments),
          '/zoom': (BuildContext context) =>
              ZoomScreen(ModalRoute.of(context).settings.arguments),
        };
        if (fullScreenDialogRoutes.containsKey(settings.name)) {
          final widgetBuilder = fullScreenDialogRoutes[settings.name];
          return Platform.isIOS
              ? CupertinoPageRoute(
                  fullscreenDialog: true,
                  settings: settings,
                  builder: (BuildContext context) => widgetBuilder(context))
              : MaterialPageRoute(
                  fullscreenDialog: true,
                  settings: settings,
                  builder: (BuildContext context) => widgetBuilder(context));
        }
        // print('onGenerateRoute: $settings');
        return null;
      },
      // onUnknownRoute: (RouteSettings settings) => MaterialPageRoute<Null>(
      //   settings: settings,
      //   builder: (BuildContext context) => UnknownPage(settings.name),
      // ),
    );
    // result = AnnotatedRegion<SystemUiOverlayStyle>(
    //   value: SystemUiOverlayStyle(
    //     statusBarColor: Colors.white,
    //     // For Android.
    //     // Use [light] for white status bar and [dark] for black status bar.
    //     statusBarIconBrightness: Brightness.dark,
    //     // For iOS.
    //     // Use [dark] for white status bar and [light] for black status bar.
    //     statusBarBrightness: Brightness.dark,
    //   ),
    //   child: result,
    // );
    print(jsonEncode(parseIdToken(authData.token)));
    // print(authData.token);
    final httpLink = HttpLink(
      uri: 'https://$kGraphQLEndpoint',
    );
    // final websocketLink = WebSocketLink(
    //   url: 'wss://$kGraphQLEndpoint',
    //   config: SocketClientConfig(
    //     autoReconnect: true,
    //     inactivityTimeout: const Duration(seconds: 30),
    //     initPayload: () async {
    //       return {
    //         'headers': {'Authorization': 'Bearer ${authData.token}'}
    //       };
    //     },
    //   ),
    // );
    final authLink = AuthLink(
      getToken: () async => 'Bearer ${authData.token}',
    );
    result = GraphQLProvider(
      client: ValueNotifier(
        GraphQLClient(
          cache: InMemoryCache(),
          // cache: NormalizedInMemoryCache(
          //   dataIdFromObject: typenameDataIdFromObject,
          // ),
          // TODO: [MVP] можно передать X-Hasura-User-Id без JWT - как отключить?
          // link: HttpLink(
          //   uri: 'https://$kGraphQLEndpoint',
          //   headers: {
          //     'X-Hasura-Role': 'user',
          //     'X-Hasura-User-Id': kFakeMemberId,
          //     // 'Authorization': 'Bearer ${authData.token}',
          //   },
          // ),
          link: authLink.concat(httpLink), // .concat(websocketLink),
        ),
      ),
      child: CacheProvider(
        child: result,
      ),
    );
    result = PersistedAppState(
      storage: JsonFileStorage(),
      child: result,
    );
    result = LifeCycleManager(
      onInitState: () {},
      onDispose: () {
        HomeShowcase.dataPool?.forEach((data) {
          data.dispose();
        });
        HomeShowcase.dataPool = null;
        HomeUnderway.dataPool?.forEach((data) {
          data.dispose();
        });
        HomeUnderway.dataPool = null;
      },
      child: result,
    );
    return result;
  }

  Future<bool> _upsertMember(GraphQLClient client) async {
    final options = MutationOptions(
      documentNode: Mutations.upsertMember,
      variables: {
        'display_name': authData.user.displayName,
        'photo_url': authData.user.photoUrl,
      },
      fetchPolicy: FetchPolicy.noCache,
    );
    return client
        .mutate(options)
        .timeout(kGraphQLMutationTimeoutDuration)
        .then<bool>((QueryResult result) {
      if (result.hasException) {
        throw result.exception;
      }
      if (result.data['insert_member']['affected_rows'] != 1) {
        throw 'Invalid insert_member.affected_rows';
      }
      appState['memberId'] = result.data['insert_member']['returning'][0]['id'];
      return true;
    }).catchError((error) {
      print(error);
    });
  }
}

// Widget need for reactive variable
class MediaQueryWrap extends StatelessWidget {
  MediaQueryWrap(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    //If the design is based on the size of the Nexus 7 (2013)
    //If you want to set the font size is scaled according to the system's "font size" assist option
    // ScreenUtil.init(width: 1920, height: 1200, allowFontScaling: true);
    // printScreenInformation();
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(textScaleFactor: 1),
      child: child,
    );
    // TODO: Responsive App https://medium.com/nonstopio/let-make-responsive-app-in-flutter-e48428795476
  }

  // void printScreenInformation() {
  //   print('Device width dp:${ScreenUtil.screenWidth}'); //Device width
  //   print('Device height dp:${ScreenUtil.screenHeight}'); //Device height
  //   print(
  //       'Device pixel density:${ScreenUtil.pixelRatio}'); //Device pixel density
  //   print(
  //       'Bottom safe zone distance dp:${ScreenUtil.bottomBarHeight}'); //Bottom safe zone distance，suitable for buttons with full screen
  //   print(
  //       'Status bar height dp:${ScreenUtil.statusBarHeight}dp'); //Status bar height , Notch will be higher Unit dp
  //   print(
  //       'Ratio of actual width dp to design draft px:${ScreenUtil().scaleWidth}');
  //   print(
  //       'Ratio of actual height dp to design draft px:${ScreenUtil().scaleHeight}');
  //   print(
  //       'The ratio of font and width to the size of the design:${ScreenUtil().scaleWidth * ScreenUtil.pixelRatio}');
  //   print(
  //       'The ratio of height width to the size of the design:${ScreenUtil().scaleHeight * ScreenUtil.pixelRatio}');
  // }
}

// String typenameDataIdFromObject(Object object) {
//   if (object is Map<String, Object> && object.containsKey('__typename')) {
//     if (object['__typename'] == 'profile') {
//       final member = object['member'] as Map<String, Object>;
//       print('profile/${member['id']}');
//       return 'profile/${member['id']}';
//     }
//   }
//   return null;
// }

// Generated using Material Design Palette/Theme Generator
// http://mcg.mbitson.com/
// https://github.com/mbitson/mcg
// const int _bluePrimary = 0xFF395afa;
// const MaterialColor mapBoxBlue = MaterialColor(
//   _bluePrimary,
//   <int, Color>{
//     50: Color(0xFFE7EBFE),
//     100: Color(0xFFC4CEFE),
//     200: Color(0xFF9CADFD),
//     300: Color(0xFF748CFC),
//     400: Color(0xFF5773FB),
//     500: Color(_bluePrimary),
//     600: Color(0xFF3352F9),
//     700: Color(0xFF2C48F9),
//     800: Color(0xFF243FF8),
//     900: Color(0xFF172EF6),
//   },
// );

class AuthData {
  AuthData({
    this.user,
    this.token,
    this.isLogin = false,
  });

  final FirebaseUser user;
  final String token;
  final bool isLogin;
}

class AuthCheck extends StatefulWidget {
  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  AuthData _authData;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthData>(
      future: _authData == null ? _getAuthData() : Future.value(_authData),
      builder: (BuildContext context, AsyncSnapshot<AuthData> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
          case ConnectionState.active:
            return CommonMaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Authentication...'),
                ),
              ),
            );
          case ConnectionState.done:
            if (snapshot.data == null) {
              return CommonMaterialApp(
                home: LoginScreen(onClose: (AuthData authData) {
                  setState(() {
                    _authData = authData;
                  });
                }),
              );
            }
            return App(authData: snapshot.data);
        }
        return null;
      },
    );
  }

  Future<AuthData> _getAuthData() async {
    try {
      final user = await FirebaseAuth.instance.currentUser();
      if (user == null) return null;
      final idToken = await user.getIdToken();
      return AuthData(user: user, token: idToken.token);
    } catch (error) {
      print(error);
      return null;
    }
  }
}

class CommonMaterialApp extends StatelessWidget {
  CommonMaterialApp({
    this.navigatorObservers = const <NavigatorObserver>[],
    this.builder,
    this.home,
    this.initialRoute,
    this.routes = const <String, WidgetBuilder>{},
    this.onGenerateRoute,
    this.onUnknownRoute,
  });

  final List<NavigatorObserver> navigatorObservers;
  final TransitionBuilder builder;
  final Widget home;
  final String initialRoute;
  final Map<String, WidgetBuilder> routes;
  final RouteFactory onGenerateRoute;
  final RouteFactory onUnknownRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // print('App build');
    return MaterialApp(
      // debugShowCheckedModeBanner: isInDebugMode,
      navigatorObservers: navigatorObservers,
      // locale: isInDebugMode ? DevicePreview.of(context).locale : null,
      // locale: DevicePreview.of(context).locale,
      // localizationsDelegates: [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      // ],
      // supportedLocales: [
      //   Locale('en', 'US'), // English
      //   Locale('ru', 'RU'), // Russian
      // ],
      title: 'minsk8',
      // theme: ThemeData(
      //   //   primarySwatch: mapBoxBlue,
      //   //   visualDensity: VisualDensity.adaptivePlatformDensity
      // ),
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          elevation: kAppBarElevation,
          iconTheme: theme.iconTheme,
          actionsIconTheme: theme.iconTheme,
          color: theme.scaffoldBackgroundColor,
          textTheme: theme.textTheme, //.apply(fontSizeFactor: 0.8),
        ),
      ),
      builder: builder ??
          (BuildContext context, Widget child) => MediaQueryWrap(child),
      home: home,
      initialRoute: initialRoute,
      routes: routes,
      onGenerateRoute: onGenerateRoute,
      onUnknownRoute: onUnknownRoute,
    );
  }
}
