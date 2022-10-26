import 'dart:async';
import 'dart:convert';
import 'package:eshop_multivendor/Screen/Product_Detail.dart';
import 'package:eshop_multivendor/Helper/Color.dart';
import 'package:eshop_multivendor/Helper/Constant.dart';
import 'package:eshop_multivendor/Helper/PushNotificationService.dart';
import 'package:eshop_multivendor/Helper/Session.dart';
import 'package:eshop_multivendor/Helper/String.dart';
import 'package:eshop_multivendor/Model/Section_Model.dart';
import 'package:eshop_multivendor/Provider/HomeProvider.dart';
import 'package:eshop_multivendor/Provider/Theme.dart';
import 'package:eshop_multivendor/Screen/Favorite.dart';
import 'package:eshop_multivendor/Screen/Login.dart';
import 'package:eshop_multivendor/Screen/MyProfile.dart';
import 'package:eshop_multivendor/Screen/explore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'All_Category.dart';
import 'Cart.dart';
import 'HomePage.dart';
import 'NotificationLIst.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<Dashboard> with TickerProviderStateMixin {
  int _selBottom = 0;
  late TabController _tabController;
  bool _isNetworkAvail = true;

  late StreamSubscription streamSubscription;

  late AnimationController navigationContainerAnimationController =
      AnimationController(
    vsync: this, // the SingleTickerProviderStateMixin
    duration: const Duration(milliseconds: 200),
  );

  DateTime? currentBackPressTime;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    initDynamicLinks();
    _tabController = TabController(
      length: 5,
      vsync: this,
    );

    final pushNotificationService = PushNotificationService(
        context: context, tabController: _tabController);
    pushNotificationService.initialise();

    _tabController.addListener(
      () {
        Future.delayed(const Duration(seconds: 0)).then(
          (value) {},
        );

        setState(
          () {
            _selBottom = _tabController.index;
          },
        );
        if (_tabController.index == 3) {
          cartTotalClear();
        }
      },
    );

    Future.delayed(Duration.zero, () {
      context.read<HomeProvider>()
        ..setAnimationController(navigationContainerAnimationController)
        ..setBottomBarOffsetToAnimateController(
            navigationContainerAnimationController)
        ..setAppBarOffsetToAnimateController(
            navigationContainerAnimationController);
    });
    super.initState();
  }

  void initDynamicLinks() async {
    streamSubscription = FirebaseDynamicLinks.instance.onLink.listen((event) {
      final Uri deepLink = event.link;
      if (deepLink.queryParameters.isNotEmpty) {
        int index = int.parse(deepLink.queryParameters['index']!);

        int secPos = int.parse(deepLink.queryParameters['secPos']!);

        String? id = deepLink.queryParameters['id'];

        String? list = deepLink.queryParameters['list'];

        getProduct(id!, index, secPos, list == 'true' ? true : false);
      }
    });

    /* FirebaseDynamicLinks.instance.onLink(
        onSuccess: (PendingDynamicLinkData? dynamicLink) async {
      final Uri? deepLink = dynamicLink?.link;

      if (deepLink != null) {
        if (deepLink.queryParameters.length > 0) {
          int index = int.parse(deepLink.queryParameters['index']!);

          int secPos = int.parse(deepLink.queryParameters['secPos']!);

          String? id = deepLink.queryParameters['id'];

          String? list = deepLink.queryParameters['list'];

          getProduct(id!, index, secPos, list == "true" ? true : false);
        }
      }
    }, onError: (OnLinkErrorException e) async {
      print(e.message);
    });
*/
    /*  final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.getInitialLink();
    final Uri? deepLink = data?.link;
    if (deepLink != null) {
      if (deepLink.queryParameters.length > 0) {
        int index = int.parse(deepLink.queryParameters['index']!);

        int secPos = int.parse(deepLink.queryParameters['secPos']!);

        String? id = deepLink.queryParameters['id'];

        // String list = deepLink.queryParameters['list'];

        getProduct(id!, index, secPos, true);
      }
    }*/
  }

  Future<void> getProduct(String id, int index, int secPos, bool list) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        var parameter = {
          ID: id,
        };

        // if (CUR_USERID != null) parameter[USER_ID] = CUR_USERID;
        Response response =
            await post(getProductApi, headers: headers, body: parameter)
                .timeout(const Duration(seconds: timeOut));

        var getdata = json.decode(response.body);
        bool error = getdata['error'];
        String msg = getdata['message'];
        if (!error) {
          var data = getdata['data'];

          List<Product> items = [];

          items = (data as List).map((data) => Product.fromJson(data)).toList();
          currentHero = homeHero;
          Navigator.of(context).push(CupertinoPageRoute(
              builder: (context) => ProductDetail(
                    index: list ? int.parse(id) : index,
                    model: list
                        ? items[0]
                        : sectionList[secPos].productList![index],
                    secPos: secPos,
                    list: list,
                  )));
        } else {
          if (msg != 'Products Not Found !') setSnackbar(msg, context);
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
      }
    } else {
      {
        if (mounted) {
          setState(() {
            _isNetworkAvail = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
          return false;
        }else{
          DateTime now = DateTime.now();

          if (currentBackPressTime == null ||
              now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
            currentBackPressTime = now;
            setSnackbar(getTranslated(context, 'Press back again to Exit')!,context);
            return Future.value(false);
          }
          return Future.value(true);
        }

        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: false,
        extendBody: true,
        backgroundColor: Theme.of(context).colorScheme.lightWhite,
        appBar: _selBottom == 0
            ? _getAppBar()
            : PreferredSize(preferredSize: Size.zero, child: Container()),
        body: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: const [
              HomePage(),
              AllCategory(),
              //Sale(),
              Explore(),
              Cart(
                fromBottom: true,
              ),
              MyProfile(),
            ],
          ),

          /*Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child:
              ),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(height: 70, child: _getBottomBar())),
              */
          /*  Align(
                alignment: Alignment.topCenter,
                child: _getAppBar()
              ),*/ /*
              */ /*
              Align(
               alignment: Alignment.bottomCenter,
                child: _getBottomBar(),
              )*/ /*
            ],
          ),*/
        ),
        bottomNavigationBar: _getBottomBar(),
      ),
    );
  }

  _getAppBar() {
    String? title;
    if (_selBottom == 1) {
      title = getTranslated(context, 'CATEGORY');
    } else if (_selBottom == 2) {
      title = getTranslated(context, 'EXPLORE');
    } else if (_selBottom == 3) {
      title = getTranslated(context, 'MYBAG');
    } else if (_selBottom == 4) {
      title = getTranslated(context, 'PROFILE');
    }
    final appBar = AppBar(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.lightWhite,
      title: _selBottom == 0
          ? SvgPicture.asset(
              'assets/images/titleicon.svg',
              height: 40,
            )
          : Text(
              title!,
              style: const TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.normal,
              ),
            ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(
              end: 10.0, bottom: 10.0, top: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(circularBorderRadius10),
              color: Theme.of(context).colorScheme.white,
            ),
            width: 40,
            child: IconButton(
              icon: SvgPicture.asset('${imagePath}fav_black.svg',
                  color: Theme.of(context)
                      .colorScheme
                      .black // Add your color here to apply your own color
                  ),
              onPressed: () {
                Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const Favorite(),
                    ));
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
              end: 10.0, bottom: 10.0, top: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(circularBorderRadius10),
              color: Theme.of(context).colorScheme.white,
            ),
            width: 40,
            child: IconButton(
              icon: SvgPicture.asset(
                '${imagePath}notification_black.svg',
                color: Theme.of(context)
                    .colorScheme
                    .black, // Add your color here to apply your own color
              ),
              onPressed: () {
                CUR_USERID != null
                    ? Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const NotificationList(),
                        )).then((value) {
                        if (value != null && value) {
                          _tabController.animateTo(1);
                        }
                      })
                    : Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const Login(),
                        ));
              },
            ),
          ),
        ),
      ],
    );

    /*return PreferredSize(
      preferredSize: appBar.preferredSize,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: context.watch<HomeProvider>().getBars ? 100 :0,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.white,
            boxShadow: [
              BoxShadow(
                  color: Theme.of(context).colorScheme.black26,
                  blurRadius: 10)
            ],
          ),
          child: appBar),
    );*/
    return PreferredSize(
        preferredSize: appBar.preferredSize,
        child: SlideTransition(
          position: context.watch<HomeProvider>().animationAppBarBarOffset,
          child: SizedBox(
              height: context.watch<HomeProvider>().getBars ? 100 : 0,
              child: appBar),
        ));
    return SlideTransition(
      position: context.watch<HomeProvider>().animationAppBarBarOffset,
      child: Container(
        height: 75,
        color: Colors.white,
        width: MediaQuery.of(context).size.width,
        child: Row(),
      ),
    );
  }

  getTabItem(String enabledImage, String disabledImage, int selectedIndex,
      String name) {
    return Wrap(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: SizedBox(
                height: 25,
                child: _selBottom == selectedIndex
                    ? Lottie.asset('assets/animation/$enabledImage',
                        repeat: false, height: 25)
                    : SvgPicture.asset(imagePath + disabledImage,
                        color: Colors.grey, height: 20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(getTranslated(context, name)!,
                  style: TextStyle(
                      color: _selBottom == selectedIndex
                          ? Theme.of(context).colorScheme.fontColor
                          : Theme.of(context).colorScheme.lightBlack,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      fontSize: 10.0),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            )
          ],
        ),
      ],
    );
  }

  Widget _getBottomBar() {
    Brightness currentBrightness = MediaQuery.of(context).platformBrightness;

    return SlideTransition(
      position: context.watch<HomeProvider>().animationNavigationBarOffset,
      child: Container(
        height: context.watch<HomeProvider>().getBars
            ? kBottomNavigationBarHeight
            : 0,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.white,
          boxShadow: [
            BoxShadow(
                color: Theme.of(context).colorScheme.black26, blurRadius: 5)
          ],
        ),
        child: Selector<ThemeNotifier, ThemeMode>(
            selector: (_, themeProvider) => themeProvider.getThemeMode(),
            builder: (context, data, child) {
              return TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: getTabItem(
                        (data == ThemeMode.system &&
                                    currentBrightness == Brightness.dark) ||
                                data == ThemeMode.dark
                            ? 'dark_active_home.json'
                            : 'light_active_home.json',
                        'home.svg',
                        0,
                        'HOME_LBL'),
                  ),
                  Tab(
                    child: getTabItem(
                        (data == ThemeMode.system &&
                                    currentBrightness == Brightness.dark) ||
                                data == ThemeMode.dark
                            ? 'dark_active_category.json'
                            : 'light_active_category.json',
                        'category.svg',
                        1,
                        'CATEGORY'),
                  ),
                  Tab(
                    child: getTabItem(
                        (data == ThemeMode.system &&
                                    currentBrightness == Brightness.dark) ||
                                data == ThemeMode.dark
                            ? 'dark_active_explorer.json'
                            : 'light_active_explorer.json',
                        'brands.svg',
                        2,
                        'EXPLORE'),
                  ),
                  Tab(
                    child: getTabItem(
                        (data == ThemeMode.system &&
                                    currentBrightness == Brightness.dark) ||
                                data == ThemeMode.dark
                            ? 'dark_active_cart.json'
                            : 'light_active_cart.json',
                        'cart.svg',
                        3,
                        'CART'),
                  ),

                  // Tab(
                  //     child: Selector<UserProvider, String>(
                  //       builder: (context, data, child) {
                  //         return Wrap(
                  //           children: [
                  //             Stack(
                  //               alignment: Alignment.center,
                  //               children: [
                  //                 Column(
                  //                   children: [
                  //                     _selBottom == 3
                  //                         ? Lottie.asset(
                  //                         (data == ThemeMode.system && currentBrightness == Brightness.dark)  || data == ThemeMode.dark
                  //                             ? 'assets/animation/dark_active_cart.json'
                  //                             : 'assets/animation/light_active_cart.json',
                  //                         repeat: false,
                  //                         height: 20)
                  //                         : SvgPicture.asset(imagePath + 'cart.svg',
                  //                         color: Colors.grey, height: 20),
                  //                     // Categories
                  //                     Padding(
                  //                       padding:
                  //                       const EdgeInsets.symmetric(vertical: 4.0),
                  //                       child: Text(getTranslated(context, 'CART')!,
                  //                           style: const TextStyle(
                  //                               color: Colors.grey,
                  //                               fontWeight: FontWeight.w400,
                  //                               fontStyle: FontStyle.normal,
                  //                               fontSize: textFontSize10),
                  //                           textAlign: TextAlign.center,
                  //                           maxLines: 1,
                  //                           overflow: TextOverflow.ellipsis),
                  //                     )
                  //                   ],
                  //                 ),
                  //               ],
                  //             ),
                  //           ],
                  //         );
                  //       },
                  //       selector: (_, homeProvider) => homeProvider.curCartCount,
                  //     )),
                  Tab(
                    child: getTabItem(
                        (data == ThemeMode.system &&
                                    currentBrightness == Brightness.dark) ||
                                data == ThemeMode.dark
                            ? 'dark_active_profile.json'
                            : 'light_active_profile.json',
                        'profile.svg',
                        4,
                        'PROFILE'),
                  ),
                ],
                indicatorColor: Colors.transparent,
                labelColor: colors.primary,
                labelStyle: const TextStyle(fontSize: textFontSize12),
              );
            }),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
