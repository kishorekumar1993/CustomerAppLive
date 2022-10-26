import 'dart:math';

import 'package:eshop_multivendor/Screen/Product_Detail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eshop_multivendor/Helper/SimBtn.dart';
import 'package:eshop_multivendor/Helper/SqliteData.dart';
import 'package:eshop_multivendor/Provider/FavoriteProvider.dart';
import 'package:eshop_multivendor/Provider/HomeProvider.dart';
import 'package:eshop_multivendor/Provider/SettingProvider.dart';
import 'package:eshop_multivendor/Provider/Theme.dart';
import 'package:eshop_multivendor/Provider/UserProvider.dart';
import 'package:eshop_multivendor/Provider/explore_provider.dart';
import 'package:eshop_multivendor/Screen/Seller_Details.dart';
import 'package:eshop_multivendor/widgets/star_rating.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:eshop_multivendor/Helper/Session.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import '../Helper/AppBtn.dart';
import '../Helper/Color.dart';
import '../Helper/Constant.dart';
import '../Helper/String.dart';
import '../Model/Section_Model.dart';
import 'HomePage.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class Explore extends StatefulWidget {
  const Explore({Key? key}) : super(key: key);

  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Explore> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int pos = 0;
  final bool _isProgress = false;
  List<Product> productList = [];
  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  bool _isNetworkAvail = true;

  String query = '';
  int notificationoffset = 0;
  int sellerListOffset = 0;
  ScrollController? productsController;
  ScrollController? sellerListController;
  bool notificationisloadmore = true,
      notificationisgettingdata = false,
      notificationisnodata = false;

  late AnimationController _animationController;
  Timer? _debounce;
  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;

  String lastStatus = '';
  String _currentLocaleId = '';
  String lastWords = '';
  final SpeechToText speech = SpeechToText();
  late StateSetter setStater;
  ChoiceChip? tagChip;
  late UserProvider userProvider;

  late TabController _tabController;

  List<Product> sellerList = [];

  int totalSellerCount = 0;

  late AnimationController listViewIconController;

  var filterList;
  String minPrice = '0', maxPrice = '0';
  List<String>? attributeNameList,
      attributeSubList,
      attributeIDList,
      selectedId = [];
  bool initializingFilterDialogFirstTime = true;

  RangeValues? _currentRangeValues;

  ChoiceChip? choiceChip;

  String selId = '';

  String sortBy = 'p.date_added', orderBy = 'DESC';

  var db = DatabaseHelper();

  @override
  void initState() {
    //productList.clear();
    notificationoffset = 0;
    productsController = ScrollController(keepScrollOffset: true);
    productsController!.addListener(_productsListScrollListener);
    sellerListController = ScrollController(keepScrollOffset: true);
    sellerListController!.addListener(_sellerListController);

    listViewIconController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));

    _controller.addListener(() {
      if (_controller.text.isEmpty) {
        if (mounted) {
          setState(() {
            query = '';
            notificationoffset = 0;
          });
        }
        getProduct('0');
      } else {
        if (_tabController.index == 0) {
          query = _controller.text;
          notificationoffset = 0;
          notificationisnodata = false;

          if (query.trim().isNotEmpty) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              if (query.trim().isNotEmpty) {
                notificationisloadmore = true;
                notificationoffset = 0;
                getProduct('0');
              }
            });
          }
        } else {
          String search = '';
          search = _controller.text;
          sellerListOffset = 0;
          context.read<HomeProvider>().setSellerLoading(true);
          if (search.trim().isNotEmpty) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              if (search.trim().isNotEmpty) {
                sellerList.clear();
                sellerListOffset = 0;
                context.read<HomeProvider>().setSellerLoading(true);
                getSeller();
              }
            });
          }
        }
      }
      ScaffoldMessenger.of(context).clearSnackBars();
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _tabController = TabController(
      length: 2,
      vsync: this,
    );
    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    buttonSqueezeanimation = Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ));
    getProduct('0');
    getSeller();
    super.initState();
  }

  _productsListScrollListener() {
    if (productsController!.offset >=
            productsController!.position.maxScrollExtent &&
        !productsController!.position.outOfRange) {
      if (mounted) {
        setState(() {
          getProduct('0');
        });
      }
    }
  }

  _sellerListController() {
    if (sellerListController!.offset >=
            sellerListController!.position.maxScrollExtent &&
        !sellerListController!.position.outOfRange) {
      if (mounted) {
        if (sellerListOffset < totalSellerCount) {
          getSeller();
          setState(() {});
        }
      }
    }
  }

  @override
  void dispose() {
    buttonController!.dispose();
    productsController!.dispose();
    sellerListController!.dispose();
    _tabController.dispose();
    _controller.dispose();
    listViewIconController.dispose();

    _animationController.dispose();
    ScaffoldMessenger.of(context).clearSnackBars();
    super.dispose();
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  Widget noInternet(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          noIntImage(),
          noIntText(context),
          noIntDec(context),
          AppBtn(
            title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
            btnAnim: buttonSqueezeanimation,
            btnCntrl: buttonController,
            onBtnSelected: () async {
              _playAnimation();

              Future.delayed(const Duration(seconds: 2)).then((_) async {
                _isNetworkAvail = await isNetworkAvailable();
                if (_isNetworkAvail) {
                  Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(
                          builder: (BuildContext context) => super.widget));
                } else {
                  await buttonController!.reverse();
                  if (mounted) setState(() {});
                }
              });
            },
          )
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
        key: _scaffoldKey,
        body: _isNetworkAvail
            ? Column(
                children: [
                  Container(
                    color: Theme.of(context).colorScheme.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 15, 10, 0),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(circularBorderRadius10)),
                        height: 44,
                        child: TextField(
                          controller: _controller,
                          autofocus: false,
                          enabled: true,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.lightWhite),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10.0),
                              ),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.transparent),
                              borderRadius: BorderRadius.all(
                                Radius.circular(10.0),
                              ),
                            ),
                            contentPadding:
                                const EdgeInsets.fromLTRB(15.0, 5.0, 0, 5.0),
                            border: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.transparent),
                              borderRadius: BorderRadius.all(
                                Radius.circular(10.0),
                              ),
                            ),
                            fillColor: Theme.of(context).colorScheme.lightWhite,
                            filled: true,
                            isDense: true,
                            hintText: getTranslated(context, 'searchHint'),
                            hintStyle: Theme.of(context)
                                .textTheme
                                .bodyText2!
                                .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.fontColor,
                                  fontSize: textFontSize12,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.normal,
                                ),
                            prefixIcon: const Padding(
                                padding: EdgeInsets.all(15.0),
                                child: Icon(Icons.search)),
                            suffixIcon: _controller.text != ''
                                ? IconButton(
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      _controller.text = '';
                                      notificationoffset = 0;
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: colors.primary,
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        lastWords = '';
                                        if (!_hasSpeech) {
                                          initSpeechState();
                                        } else {
                                          showSpeechDialog();
                                        }
                                      },
                                      child: Selector<ThemeNotifier, ThemeMode>(
                                          selector: (_, themeProvider) =>
                                              themeProvider.getThemeMode(),
                                          builder: (context, data, child) {
                                            return (data == ThemeMode.system &&
                                                        MediaQuery.of(context)
                                                                .platformBrightness ==
                                                            Brightness.light) ||
                                                    data == ThemeMode.light
                                                ? SvgPicture.asset(
                                                    '${imagePath}voice_search.svg',
                                                    height: 15,
                                                    width: 15,
                                                  )
                                                : SvgPicture.asset(
                                                    '${imagePath}voice_search_white.svg',
                                                    height: 15,
                                                    width: 15,
                                                  );
                                          }),
                                    )),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    color: Theme.of(context).colorScheme.white,
                    child: TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(
                          child: Text(getTranslated(context, 'ALL_PRODUCTS')!),
                        ),
                        Tab(
                          child: Text(getTranslated(context, 'ALL_SELLERS')!),
                        ),
                      ],
                      indicatorColor: colors.primary,
                      labelColor: Theme.of(context).colorScheme.fontColor,
                      indicatorSize: TabBarIndicatorSize.tab,
                      unselectedLabelColor:
                          Theme.of(context).colorScheme.lightBlack,
                      labelStyle: const TextStyle(
                        fontSize: textFontSize16,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Stack(
                          children: <Widget>[
                            _showContentOfProducts(),
                            Center(
                                child: showCircularProgress(
                                    _isProgress, colors.primary)),
                          ],
                        ),
                        Stack(
                          children: <Widget>[
                            _showContentOfSellers(),
                            Selector<HomeProvider, bool>(
                              builder: (context, data, child) {
                                return Center(
                                  child: showCircularProgress(
                                      data, colors.primary),
                                );
                              },
                              selector: (_, provider) => provider.sellerLoading,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : noInternet(context));
  }

  void getAvailVarient(List<Product> tempList) {
    for (int j = 0; j < tempList.length; j++) {
      if (tempList[j].stockType == '2') {
        for (int i = 0; i < tempList[j].prVarientList!.length; i++) {
          if (tempList[j].prVarientList![i].availability == '1') {
            tempList[j].selVarient = i;

            break;
          }
        }
      }
    }
    if (notificationoffset == 0) {
      productList = [];
    }

    productList.addAll(tempList);

    debugPrint('length is  ${productList.length}');
    notificationisloadmore = true;
    notificationoffset = notificationoffset + perPage;
  }

  Future getProduct(String? showTopRated) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (notificationisloadmore) {
          if (mounted) {
            setState(() {
              notificationisloadmore = false;
              notificationisgettingdata = true;
            });
          }

          var parameter = {
            LIMIT: perPage.toString(),
            OFFSET: notificationoffset.toString(),
            SORT: sortBy,
            ORDER: orderBy,
            TOP_RETAED: showTopRated,
          };

          if (selId != '') {
            parameter[ATTRIBUTE_VALUE_ID] = selId;
          }

          if (query.trim() != '') {
            parameter[SEARCH] = query.trim();
          }

          if (_currentRangeValues != null &&
              _currentRangeValues!.start.round().toString() != '0') {
            parameter[MINPRICE] = _currentRangeValues!.start.round().toString();
          }

          if (_currentRangeValues != null &&
              _currentRangeValues!.end.round().toString() != '0') {
            parameter[MAXPRICE] = _currentRangeValues!.end.round().toString();
          }

          if (CUR_USERID != null) parameter[USER_ID] = CUR_USERID!;

          Response response =
              await post(getProductApi, headers: headers, body: parameter)
                  .timeout(const Duration(seconds: timeOut));

          var getdata = json.decode(response.body);

          bool error = getdata['error'];

          String? search = getdata['search'];

          context.read<ExploreProvider>().setProductTotal(getdata['total'] ??
              context.read<ExploreProvider>().totalProducts);
          notificationisgettingdata = false;
          if (notificationoffset == 0) notificationisnodata = error;

          if (!error && search!.trim() == query.trim()) {
            if (mounted) {
              if (initializingFilterDialogFirstTime) {
                filterList = getdata['filters'];

                minPrice = getdata[MINPRICE].toString();
                maxPrice = getdata[MAXPRICE].toString();
                _currentRangeValues =
                    RangeValues(double.parse(minPrice), double.parse(maxPrice));
                initializingFilterDialogFirstTime = false;
              }

              Future.delayed(
                  Duration.zero,
                  () => setState(() {
                        List mainlist = getdata['data'];
                        if (mainlist.isNotEmpty) {
                          List<Product> items = [];
                          List<Product> allitems = [];

                          items.addAll(mainlist
                              .map((data) => Product.fromJson(data))
                              .toList());

                          allitems.addAll(items);

                          getAvailVarient(allitems);
                        } else {
                          notificationisloadmore = false;
                        }
                      }));
            }
          } else {
            notificationisloadmore = false;
            if (mounted) setState(() {});
          }
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!);
        if (mounted) {
          setState(() {
            notificationisloadmore = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  void getSeller() {
    Map parameter = {
      LIMIT: perPage.toString(),
      OFFSET: sellerListOffset.toString(),
    };

    if (_controller.text != '') {
      parameter = {
        SEARCH: _controller.text.trim(),
      };
    }

    apiBaseHelper.postAPICall(getSellerApi, parameter).then((getdata) {
      bool error = getdata['error'];
      String? msg = getdata['message'];
      List<Product> tempSellerList = [];
      tempSellerList.clear();

      if (!error) {
        totalSellerCount = int.parse(getdata['total']);
        var data = getdata['data'];

        tempSellerList =
            (data as List).map((data) => Product.fromSeller(data)).toList();
        sellerListOffset += perPage;
        setState(() {});
      } else {
        setSnackbar(
          msg!,
        );
      }
      sellerList.addAll(tempSellerList);
      context.read<HomeProvider>().setSellerLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString());
      context.read<HomeProvider>().setSellerLoading(false);
    });

    setState(() {});
  }

  setSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.black),
      ),
      backgroundColor: Theme.of(context).colorScheme.white,
      elevation: 1.0,
    ));
  }

  clearAll() {
    setState(() {
      query = _controller.text;
      notificationoffset = 0;
      notificationisloadmore = true;
      productList.clear();
    });
  }

  _showContentOfSellers() {
    return sellerList.isNotEmpty
        ? ListView.builder(
            shrinkWrap: true,
            controller: sellerListController,
            itemCount: sellerList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.white,
                  child: ListTile(
                      title: Text(
                        sellerList[index].store_name!,
                        style: Theme.of(context).textTheme.subtitle2!.copyWith(
                            color: Theme.of(context).colorScheme.lightBlack,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StarRating(
                                noOfRatings:
                                    sellerList[index].noOfRatingsOnSeller!,
                                totalRating: sellerList[index].seller_rating!,
                                needToShowNoOfRatings: false),
                          ),
                          Text(
                              '| ${sellerList[index].totalProductsOfSeller} Products',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.normal,
                                  fontSize: textFontSize14)),
                        ],
                      ),
                      leading: ClipRRect(
                          borderRadius: BorderRadius.circular(7.0),
                          child: sellerList[index].seller_profile == ''
                              ? Image.asset(
                                  'assets/images/placeholder.png',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                )
                              : FadeInImage(
                                  image: CachedNetworkImageProvider(
                                      sellerList[index].seller_profile!),
                                  fadeInDuration:
                                      const Duration(milliseconds: 10),
                                  fit: BoxFit.cover,
                                  height: 50,
                                  width: 50,
                                  placeholder: placeHolder(50),
                                  imageErrorBuilder:
                                      (context, error, stackTrace) =>
                                          erroWidget(50),
                                )),
                      trailing: Container(
                          width: 80,
                          height: 35,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              3.0, 0, 3.0, 0),
                          decoration: BoxDecoration(
                              border:
                                  Border.all(width: 2, color: colors.primary),
                              borderRadius: BorderRadius.circular(
                                  circularBorderRadius10)),
                          child: Center(
                            child: Text(getTranslated(context, 'VIEW_STORE')!,
                                style: const TextStyle(color: colors.primary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                softWrap: true),
                          )),
                      onTap: () async {
                        Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (BuildContext context) =>
                                    SellerProfile(
                                      sellerID: sellerList[index].seller_id!,
                                      sellerImage:
                                          sellerList[index].seller_profile!,
                                      sellerName:
                                          sellerList[index].seller_name!,
                                      sellerRating:
                                          sellerList[index].seller_rating!,
                                      sellerStoreName:
                                          sellerList[index].store_name!,
                                      storeDesc:
                                          sellerList[index].store_description!,
                                    )));
                      }),
                ),
              );
            })
        : Selector<HomeProvider, bool>(
            builder: (context, data, child) {
              return !data
                  ? Center(
                      child: Text(
                          getTranslated(context, 'No Seller/Store Found')!))
                  : Container();
            },
            selector: (_, provider) => provider.sellerLoading,
          );
  }

  _showContentOfProducts() {
    return Column(
      children: <Widget>[
        sortAndFilterOption(),
        searchResult(),
        Expanded(
            child: notificationisnodata
                ? getNoItem(context)
                : Stack(
                    children: [
                      context.watch<ExploreProvider>().getCurrentView !=
                              'GridView'
                          ? getListviewLayoutOfProducts()
                          : getGridviewLayoutOfProducts(),
                      notificationisgettingdata
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : Container(),
                    ],
                  )),
      ],
    );
  }

  Future<void> initSpeechState() async {
    var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: false,
        finalTimeout: const Duration(milliseconds: 0));
    if (hasSpeech) {
      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';
    }

    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
    if (hasSpeech) showSpeechDialog();
  }

  void errorListener(SpeechRecognitionError error) {}

  void statusListener(String status) {
    setStater(() {
      lastStatus = status;
    });
  }

  void startListening() {
    lastWords = '';
    speech.listen(
        onResult: resultListener,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        listenMode: ListenMode.confirmation);
    setStater(() {});
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);

    setStater(() {
      this.level = level;
    });
  }

  void stopListening() {
    speech.stop();
    setStater(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setStater(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    setStater(() {
      lastWords = result.recognizedWords;
      query = lastWords;
    });

    if (result.finalResult) {
      Future.delayed(const Duration(seconds: 1)).then((_) async {
        clearAll();

        _controller.text = lastWords;
        _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length));

        setState(() {});
        Navigator.of(context).pop();
      });
    }
  }

  showSpeechDialog() {
    return dialogAnimate(context, StatefulBuilder(
        builder: (BuildContext context, StateSetter setStater1) {
      setStater = setStater1;
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.lightWhite,
        title: Text(
          getTranslated(context, 'SEarchHint')!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.fontColor,
            fontWeight: FontWeight.bold,
            fontSize: textFontSize16,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      blurRadius: .26,
                      spreadRadius: level * 1.5,
                      color:
                          Theme.of(context).colorScheme.black.withOpacity(.05))
                ],
                color: Theme.of(context).colorScheme.white,
                borderRadius: const BorderRadius.all(Radius.circular(50)),
              ),
              child: IconButton(
                  icon: const Icon(
                    Icons.mic,
                    color: colors.primary,
                  ),
                  onPressed: () {
                    if (!_hasSpeech) {
                      initSpeechState();
                    } else {
                      !_hasSpeech || speech.isListening
                          ? null
                          : startListening();
                    }
                  }),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(lastWords),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Theme.of(context).colorScheme.fontColor.withOpacity(0.1),
              child: Center(
                child: speech.isListening
                    ? Text(
                        "I'm listening...",
                        style: Theme.of(context).textTheme.subtitle2!.copyWith(
                            color: Theme.of(context).colorScheme.fontColor,
                            fontWeight: FontWeight.bold),
                      )
                    : Text(
                        'Not listening',
                        style: Theme.of(context).textTheme.subtitle2!.copyWith(
                            color: Theme.of(context).colorScheme.fontColor,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      );
    }));
  }

  void sortDialog() {
    showModalBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.white,
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      builder: (builder) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                            top: 19.0, bottom: 16.0),
                        child: Text(
                          getTranslated(context, 'SORT_BY')!,
                          style: Theme.of(context)
                              .textTheme
                              .headline6!
                              .copyWith(
                                color: Theme.of(context).colorScheme.fontColor,
                              ),
                        )),
                  ),
                  InkWell(
                    onTap: () {
                      sortBy = '';
                      orderBy = 'DESC';
                      if (mounted) {
                        setState(() {
                          //_isLoading = true;

                          notificationoffset = 0;
                          productList.clear();
                        });
                      }
                      getProduct('1');
                      Navigator.pop(context, 'option 1');
                    },
                    child: Container(
                      width: deviceWidth,
                      color: sortBy == ''
                          ? colors.primary
                          : Theme.of(context).colorScheme.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      child: Text(getTranslated(context, 'TOP_RATED')!,
                          style: Theme.of(context)
                              .textTheme
                              .subtitle1!
                              .copyWith(
                                  color: sortBy == ''
                                      ? Theme.of(context).colorScheme.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .fontColor)),
                    ),
                  ),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'p.date_added' && orderBy == 'DESC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(getTranslated(context, 'F_NEWEST')!,
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle1!
                                  .copyWith(
                                      color: sortBy == 'p.date_added' &&
                                              orderBy == 'DESC'
                                          ? Theme.of(context).colorScheme.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .fontColor))),
                      onTap: () {
                        sortBy = 'p.date_added';
                        orderBy = 'DESC';
                        if (mounted) {
                          setState(() {
                            //   _isLoading = true;

                            notificationoffset = 0;
                            productList.clear();
                          });
                        }
                        getProduct('0');
                        Navigator.pop(context, 'option 1');
                      }),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'p.date_added' && orderBy == 'ASC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(
                            getTranslated(context, 'F_OLDEST')!,
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1!
                                .copyWith(
                                    color: sortBy == 'p.date_added' &&
                                            orderBy == 'ASC'
                                        ? Theme.of(context).colorScheme.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                          )),
                      onTap: () {
                        sortBy = 'p.date_added';
                        orderBy = 'ASC';
                        if (mounted) {
                          setState(() {
                            //    _isLoading = true;

                            notificationoffset = 0;
                            productList.clear();
                          });
                        }
                        getProduct('0');
                        Navigator.pop(context, 'option 2');
                      }),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'pv.price' && orderBy == 'ASC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(
                            getTranslated(context, 'F_LOW')!,
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1!
                                .copyWith(
                                    color: sortBy == 'pv.price' &&
                                            orderBy == 'ASC'
                                        ? Theme.of(context).colorScheme.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                          )),
                      onTap: () {
                        sortBy = 'pv.price';
                        orderBy = 'ASC';
                        if (mounted) {
                          setState(() {
                            //      _isLoading = true;

                            notificationoffset = 0;
                            productList.clear();
                          });
                        }
                        getProduct('0');
                        Navigator.pop(context, 'option 3');
                      }),
                  InkWell(
                      child: Container(
                          width: deviceWidth,
                          color: sortBy == 'pv.price' && orderBy == 'DESC'
                              ? colors.primary
                              : Theme.of(context).colorScheme.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Text(
                            getTranslated(context, 'F_HIGH')!,
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1!
                                .copyWith(
                                    color: sortBy == 'pv.price' &&
                                            orderBy == 'DESC'
                                        ? Theme.of(context).colorScheme.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                          )),
                      onTap: () {
                        sortBy = 'pv.price';
                        orderBy = 'DESC';
                        if (mounted) {
                          setState(() {
                            //        _isLoading = true;

                            notificationoffset = 0;
                            productList.clear();
                          });
                        }
                        getProduct('0');
                        Navigator.pop(context, 'option 4');
                      }),
                ]),
          );
        });
      },
    );
  }

  sortAndFilterOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Container(
        color: Theme.of(context).colorScheme.white,
        height: 45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 20),
                child: GestureDetector(
                  onTap: sortDialog,
                  child: Row(
                    children: [
                      Text(
                        getTranslated(context, 'SORT_BY')!,
                        style: const TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.normal,
                            fontSize: textFontSize12),
                        textAlign: TextAlign.start,
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_sharp,
                        size: 16,
                      )
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: 3.0,
                    ),
                    child: InkWell(
                      child: AnimatedIcon(
                        textDirection: TextDirection.ltr,
                        icon: AnimatedIcons.list_view,
                        progress: listViewIconController,
                      ),
                      onTap: () {
                        if (productList.isNotEmpty) {
                          if (context.read<ExploreProvider>().view ==
                              'ListView') {
                            context
                                .read<ExploreProvider>()
                                .changeViewTo('GridView');
                          } else {
                            context
                                .read<ExploreProvider>()
                                .changeViewTo('ListView');
                          }
                        }
                        context.read<ExploreProvider>().view == 'ListView'
                            ? listViewIconController.forward()
                            : listViewIconController.reverse();
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  const Text(' | '),
                  GestureDetector(
                    onTap: filterDialog,
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined),
                        Text(
                          getTranslated(context, 'FILTER')!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.fontColor,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  searchResult() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Container(
        color: Theme.of(context).colorScheme.white,
        height: 45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 20),
                child: Text(
                  getTranslated(context, 'TITLE1_LBL')!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.fontColor,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.normal,
                      fontSize: textFontSize16),
                  textAlign: TextAlign.start,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 20),
              child: Selector<ExploreProvider, String>(
                builder: (context, totalProducts, child) {
                  return Text(
                      '$totalProducts ${getTranslated(context, "Items_Found")}');
                },
                selector: (_, exploreProvider) => exploreProvider.totalProducts,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void filterDialog() {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      builder: (builder) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
                padding: const EdgeInsetsDirectional.only(top: 30.0),
                child: AppBar(
                  title: Text(
                    getTranslated(context, 'FILTER')!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.fontColor,
                    ),
                  ),
                  centerTitle: true,
                  elevation: 5,
                  backgroundColor: Theme.of(context).colorScheme.white,
                  leading: Builder(builder: (BuildContext context) {
                    return Container(
                      margin: const EdgeInsets.all(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsetsDirectional.only(end: 4.0),
                          child: Icon(Icons.arrow_back_ios_rounded,
                              color: colors.primary),
                        ),
                      ),
                    );
                  }),
                )),
            Expanded(
                child: Container(
              color: Theme.of(context).colorScheme.lightWhite,
              padding: const EdgeInsetsDirectional.only(
                  start: 7.0, end: 7.0, top: 7.0),
              child: filterList != null
                  ? ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      padding: const EdgeInsetsDirectional.only(top: 10.0),
                      itemCount: filterList.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            children: [
                              SizedBox(
                                  width: deviceWidth,
                                  child: Card(
                                      elevation: 0,
                                      child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Price Range',
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1!
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .lightBlack,
                                                    fontWeight:
                                                        FontWeight.normal),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          )))),
                              RangeSlider(
                                values: _currentRangeValues!,
                                min: double.parse(minPrice),
                                max: double.parse(maxPrice),
                                divisions: 10,
                                labels: RangeLabels(
                                  _currentRangeValues!.start.round().toString(),
                                  _currentRangeValues!.end.round().toString(),
                                ),
                                onChanged: (RangeValues values) {
                                  setState(() {
                                    _currentRangeValues = values;
                                  });
                                },
                              ),
                            ],
                          );
                        } else {
                          index = index - 1;
                          attributeSubList =
                              filterList[index]['attribute_values'].split(',');

                          attributeIDList = filterList[index]
                                  ['attribute_values_id']
                              .split(',');

                          List<Widget?> chips = [];
                          List<String> att =
                              filterList[index]['attribute_values']!.split(',');

                          List<String> attSType =
                              filterList[index]['swatche_type'].split(',');

                          List<String> attSValue =
                              filterList[index]['swatche_value'].split(',');

                          for (int i = 0; i < att.length; i++) {
                            Widget itemLabel;
                            if (attSType[i] == '1') {
                              String clr = (attSValue[i].substring(1));

                              String color = '0xff$clr';

                              itemLabel = Container(
                                width: 25,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(int.parse(color))),
                              );
                            } else if (attSType[i] == '2') {
                              itemLabel = ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.network(attSValue[i],
                                      width: 80,
                                      height: 80,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              erroWidget(80)));
                            } else {
                              itemLabel = Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(att[i],
                                    style: TextStyle(
                                        color: selectedId!
                                                .contains(attributeIDList![i])
                                            ? Theme.of(context)
                                                .colorScheme
                                                .white
                                            : Theme.of(context)
                                                .colorScheme
                                                .fontColor)),
                              );
                            }

                            choiceChip = ChoiceChip(
                              selected:
                                  selectedId!.contains(attributeIDList![i]),
                              label: itemLabel,
                              labelPadding: const EdgeInsets.all(0),
                              selectedColor: colors.primary,
                              backgroundColor:
                                  Theme.of(context).colorScheme.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    attSType[i] == '1' ? 100 : 10),
                                side: BorderSide(
                                    color: selectedId!
                                            .contains(attributeIDList![i])
                                        ? colors.primary
                                        : colors.black12,
                                    width: 1.5),
                              ),
                              onSelected: (bool selected) {
                                attributeIDList = filterList[index]
                                        ['attribute_values_id']
                                    .split(',');

                                if (mounted) {
                                  setState(() {
                                    if (selected == true) {
                                      selectedId!.add(attributeIDList![i]);
                                    } else {
                                      selectedId!.remove(attributeIDList![i]);
                                    }
                                  });
                                }
                              },
                            );

                            chips.add(choiceChip);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: deviceWidth,
                                child: Card(
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      filterList[index]['name'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .subtitle1!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .fontColor,
                                              fontWeight: FontWeight.normal),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ),
                              chips.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Wrap(
                                        children:
                                            chips.map<Widget>((Widget? chip) {
                                          return Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: chip,
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  : Container()

                              /*    (filter == filterList[index]["name"])
                              ? ListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      NeverScrollableScrollPhysics(),
                                  itemCount: attributeIDList!.length,
                                  itemBuilder: (context, i) {

                                    */ /*       return CheckboxListTile(
                                  dense: true,
                                  title: Text(attributeSubList![i],
                                      style: Theme.of(context)
                                          .textTheme
                                          .subtitle1!
                                          .copyWith(
                                              color: Theme.of(context).colorScheme.lightBlack,
                                              fontWeight:
                                                  FontWeight.normal)),
                                  value: selectedId
                                      .contains(attributeIDList![i]),
                                  activeColor: colors.primary,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (bool? val) {
                                    if (mounted)
                                      setState(() {
                                        if (val == true) {
                                          selectedId.add(attributeIDList![i]);
                                        } else {
                                          selectedId
                                              .remove(attributeIDList![i]);
                                        }
                                      });
                                  },
                                );*/ /*
                                  })
                              : Container()*/
                            ],
                          );
                        }
                      })
                  : Container(),
            )),
            Container(
              color: Theme.of(context).colorScheme.white,
              child: Row(children: <Widget>[
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 20),
                  width: deviceWidth! * 0.4,
                  child: OutlinedButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          selectedId!.clear();
                        });
                      }
                    },
                    child: Text(getTranslated(context, 'DISCARD')!),
                  ),
                ),
                const Spacer(),
                SimBtn(
                    borderRadius: circularBorderRadius5,
                    size: 0.4,
                    title: getTranslated(context, 'APPLY'),
                    onBtnSelected: () {
                      if (selectedId != null) {
                        selId = selectedId!.join(',');
                      }

                      if (mounted) {
                        setState(() {
                          //_isLoading = true;

                          notificationoffset = 0;
                          productList.clear();
                        });
                      }
                      getProduct('0');
                      Navigator.pop(context, 'Product Filter');
                    }),
              ]),
            )
          ]);
        });
      },
    );
  }

  getGridviewLayoutOfProducts() {
    return Padding(
      padding: const EdgeInsets.only(right: 10, left: 10),
      child: GridView.count(
        controller: productsController,
        padding: const EdgeInsetsDirectional.only(top: 5),
        crossAxisCount: 2,
        shrinkWrap: true,
        childAspectRatio: 0.750,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        physics: const BouncingScrollPhysics(),
        children: List.generate(
          productList.length,
          (index) {
            return productItem(index);
          },
        ),
      ),
    );
  }

  Widget productItem(int index) {
    if (productList.length > index) {
      String? offPer;
      double price =
          double.parse(productList[index].prVarientList![0].disPrice!);
      if (price == 0) {
        price = double.parse(productList[index].prVarientList![0].price!);
      } else {
        double off =
            double.parse(productList[index].prVarientList![0].price!) - price;
        offPer = ((off * 100) /
                double.parse(productList[index].prVarientList![0].price!))
            .toStringAsFixed(2);
      }

      double width = deviceWidth! * 0.5;
      Product model = productList[index];
      return Card(
        elevation: 0.2,
        margin: const EdgeInsetsDirectional.only(bottom: 2, end: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5),
                          topRight: Radius.circular(5)),
                      child: Hero(
                        transitionOnUserGestures: true,
                        tag: '${productList[index].id}$index',
                        child: FadeInImage(
                          fadeInDuration: const Duration(milliseconds: 150),
                          image: CachedNetworkImageProvider(
                              productList[index].image!),
                          height: double.maxFinite,
                          width: double.maxFinite,
                          imageErrorBuilder: (context, error, stackTrace) =>
                              erroWidget(double.maxFinite),
                          fit: BoxFit.cover,
                          placeholder: placeHolder(width),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 10.0,
                      top: 15,
                    ),
                    child: Text(
                      productList[index].name!,
                      style: Theme.of(context).textTheme.caption!.copyWith(
                            color: Theme.of(context).colorScheme.lightBlack,
                            fontSize: textFontSize10,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.normal,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 10.0,
                      top: 5,
                    ),
                    child: Row(
                      children: [
                        Text(
                          ' ${getPriceFormat(context, price)!}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.blue,
                            fontSize: textFontSize14,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  double.parse(
                              productList[index].prVarientList![0].disPrice!) !=
                          0
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 10.0,
                            top: 5,
                          ),
                          child: Row(
                            children: <Widget>[
                              Text(
                                double.parse(productList[index]
                                            .prVarientList![0]
                                            .disPrice!) !=
                                        0
                                    ? '${getPriceFormat(context, double.parse(productList[index].prVarientList![0].price!))}'
                                    : '',
                                style: Theme.of(context)
                                    .textTheme
                                    .overline!
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      letterSpacing: 0,
                                      fontSize: textFontSize10,
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.normal,
                                    ),
                              ),
                              Flexible(
                                child: Text(
                                  '   ${double.parse(offPer!).round().toStringAsFixed(2)}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .overline!
                                      .copyWith(
                                        color: colors.primary,
                                        letterSpacing: 0,
                                        fontSize: textFontSize10,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: 10.0, top: 10, bottom: 5.0),
                    child: productList[index].rating != '0.00'
                        ? StarRating(
                            totalRating: productList[index].rating!,
                            noOfRatings: productList[index].noOfRating!,
                            needToShowNoOfRatings: true)
                        : Container(
                            height: 20,
                          ),
                  )
                ],
              ),
              Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: 0,
                  end: 0,
                  child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.white,
                          borderRadius: const BorderRadiusDirectional.only(
                              bottomStart:
                                  Radius.circular(circularBorderRadius10),
                              topEnd: Radius.circular(5))),
                      child: model.isFavLoading!
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 0.7,
                                  )),
                            )
                          : Selector<FavoriteProvider, List<String?>>(
                              builder: (context, data, child) {
                                return InkWell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      !data.contains(model.id)
                                          ? Icons.favorite_border
                                          : Icons.favorite,
                                      size: 20,
                                    ),
                                  ),
                                  onTap: () {
                                    if (CUR_USERID != null) {
                                      !data.contains(model.id)
                                          ? _setFav(index, model)
                                          : _removeFav(index, model);
                                    } else {
                                      if (!data.contains(model.id)) {
                                        model.isFavLoading = true;
                                        model.isFav = '1';
                                        context
                                            .read<FavoriteProvider>()
                                            .addFavItem(model);
                                        db.addAndRemoveFav(model.id!, true);
                                        model.isFavLoading = false;
                                      } else {
                                        model.isFavLoading = true;
                                        model.isFav = '0';
                                        context
                                            .read<FavoriteProvider>()
                                            .removeFavItem(
                                                model.prVarientList![0].id!);
                                        db.addAndRemoveFav(model.id!, false);
                                        model.isFavLoading = false;
                                      }
                                      setState(() {});
                                    }
                                  },
                                );
                              },
                              selector: (_, provider) => provider.favIdList,
                            )))
            ],
          ),
          onTap: () {
            Product model = productList[index];
            Navigator.push(
              context,
              PageRouteBuilder(
                // transitionDuration: Duration(milliseconds: 150),
                pageBuilder: (_, __, ___) => ProductDetail(
                    model: model, secPos: 0, index: index, list: false
                    //  title: sectionList[secPos].title,
                    ),
              ),
            );
          },
        ),
      );
    } else {
      return Container();
    }
  }

  Widget getListviewLayoutOfProducts() {
    return ListView.builder(
        itemCount: productList.length,
        shrinkWrap: true,
        controller: productsController,
        itemBuilder: (BuildContext context, int index) {
          String? offPer;
          double price =
              double.parse(productList[index].prVarientList![0].disPrice!);
          if (price == 0) {
            price = double.parse(productList[index].prVarientList![0].price!);
          } else {
            double off =
                double.parse(productList[index].prVarientList![0].price!) -
                    price;
            offPer = ((off * 100) /
                    double.parse(productList[index].prVarientList![0].price!))
                .toStringAsFixed(2);
          }

          Product model = productList[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 10.0, end: 10.0, top: 5.0),
            child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.white,
                  borderRadius: BorderRadius.circular(circularBorderRadius10)),
              child: InkWell(
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            flex: 1,
                            child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4)),
                                child: FadeInImage(
                                  image: CachedNetworkImageProvider(
                                      productList[index].image!),
                                  fadeInDuration:
                                      const Duration(milliseconds: 10),
                                  fit: BoxFit.cover,
                                  height: 107,
                                  width: 107,
                                  placeholder: placeHolder(50),
                                  imageErrorBuilder:
                                      (context, error, stackTrace) =>
                                          erroWidget(50),
                                )),
                          ),
                          Flexible(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      top: 15.0, start: 15.0),
                                  child: Text(
                                    productList[index].name!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .subtitle2!
                                        .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .lightBlack,
                                            fontWeight: FontWeight.w400,
                                            fontStyle: FontStyle.normal,
                                            fontSize: textFontSize12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 15.0, top: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        getPriceFormat(context, price)!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .blue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        width: 3,
                                      ),
                                      Text(
                                        double.parse(productList[index]
                                                    .prVarientList![0]
                                                    .disPrice!) !=
                                                0
                                            ? getPriceFormat(
                                                context,
                                                double.parse(productList[index]
                                                    .prVarientList![0]
                                                    .price!))!
                                            : '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .overline!
                                            .copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                letterSpacing: 0),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      top: 8.0, start: 15.0),
                                  child: StarRating(
                                    noOfRatings: productList[index].noOfRating!,
                                    totalRating: productList[index].rating!,
                                    needToShowNoOfRatings: true,
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                      Positioned.directional(
                          textDirection: Directionality.of(context),
                          top: 0,
                          end: 0,
                          child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: model.isFavLoading!
                                  ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 0.7,
                                          )),
                                    )
                                  : Selector<FavoriteProvider, List<String?>>(
                                      builder: (context, data, child) {
                                        return InkWell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              !data.contains(model.id)
                                                  ? Icons.favorite_border
                                                  : Icons.favorite,
                                              size: 20,
                                            ),
                                          ),
                                          onTap: () {
                                            if (CUR_USERID != null) {
                                              !data.contains(model.id)
                                                  ? _setFav(index, model)
                                                  : _removeFav(index, model);
                                            } else {
                                              if (!data.contains(model.id)) {
                                                model.isFavLoading = true;
                                                model.isFav = '1';
                                                context
                                                    .read<FavoriteProvider>()
                                                    .addFavItem(model);
                                                db.addAndRemoveFav(
                                                    model.id!, true);
                                                model.isFavLoading = false;
                                              } else {
                                                model.isFavLoading = true;
                                                model.isFav = '0';
                                                context
                                                    .read<FavoriteProvider>()
                                                    .removeFavItem(model
                                                        .prVarientList![0].id!);
                                                db.addAndRemoveFav(
                                                    model.id!, false);
                                                model.isFavLoading = false;
                                              }
                                              setState(() {});
                                            }
                                          },
                                        );
                                      },
                                      selector: (_, provider) =>
                                          provider.favIdList,
                                    )))
                    ],
                  ),
                  onTap: () async {
                    SettingProvider settingsProvider =
                        Provider.of<SettingProvider>(context, listen: false);

                    /* settingsProvider.setPrefrenceList(
                        HISTORYLIST, textController!.text.toString().trim());*/

                    Product model = productList[index];
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                          // transitionDuration: Duration(seconds: 1),
                          pageBuilder: (_, __, ___) => ProductDetail(
                                model: model,
                                secPos: 0,
                                index: index,
                                list: true,
                              )),
                    );
                  }),
            ),
          );
        });
  }

  _setFav(int index, Product model) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = true
                : productList[index].isFavLoading = true;
          });
        }

        var parameter = {USER_ID: CUR_USERID, PRODUCT_ID: model.id};
        Response response =
            await post(setFavoriteApi, body: parameter, headers: headers)
                .timeout(const Duration(seconds: timeOut));

        var getdata = json.decode(response.body);

        bool error = getdata['error'];
        String? msg = getdata['message'];
        if (!error) {
          index == -1 ? model.isFav = '1' : productList[index].isFav = '1';

          context.read<FavoriteProvider>().addFavItem(model);
        } else {
          setSnackbar(msg!);
        }

        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = false
                : productList[index].isFavLoading = false;
          });
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  _removeFav(int index, Product model) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = true
                : productList[index].isFavLoading = true;
          });
        }

        var parameter = {USER_ID: CUR_USERID, PRODUCT_ID: model.id};
        Response response =
            await post(removeFavApi, body: parameter, headers: headers)
                .timeout(const Duration(seconds: timeOut));

        var getdata = json.decode(response.body);
        bool error = getdata['error'];
        String? msg = getdata['message'];
        if (!error) {
          index == -1 ? model.isFav = '0' : productList[index].isFav = '0';
          context
              .read<FavoriteProvider>()
              .removeFavItem(model.prVarientList![0].id!);
        } else {
          setSnackbar(msg!);
        }

        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = false
                : productList[index].isFavLoading = false;
          });
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!);
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }
}
