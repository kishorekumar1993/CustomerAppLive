import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eshop_multivendor/Helper/ApiBaseHelper.dart';
import 'package:eshop_multivendor/Helper/AppBtn.dart';
import 'package:eshop_multivendor/Helper/Color.dart';
import 'package:eshop_multivendor/Helper/Constant.dart';
import 'package:eshop_multivendor/Helper/Session.dart';
import 'package:eshop_multivendor/Helper/SimBtn.dart';
import 'package:eshop_multivendor/Helper/SqliteData.dart';
import 'package:eshop_multivendor/Helper/String.dart';
import 'package:eshop_multivendor/Model/Model.dart';
import 'package:eshop_multivendor/Model/Section_Model.dart';
import 'package:eshop_multivendor/Provider/CartProvider.dart';
import 'package:eshop_multivendor/Provider/CategoryProvider.dart';
import 'package:eshop_multivendor/Provider/FavoriteProvider.dart';
import 'package:eshop_multivendor/Provider/HomeProvider.dart';
import 'package:eshop_multivendor/Provider/SettingProvider.dart';
import 'package:eshop_multivendor/Provider/Theme.dart';
import 'package:eshop_multivendor/Provider/UserProvider.dart';
import 'package:eshop_multivendor/Screen/Product_Detail.dart';
import 'package:eshop_multivendor/Screen/Search.dart';
import 'package:eshop_multivendor/Screen/SellerList.dart';
import 'package:eshop_multivendor/Screen/Seller_Details.dart';
import 'package:eshop_multivendor/Screen/SubCategory.dart';
import 'package:eshop_multivendor/widgets/star_rating.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info/package_info.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import '../Provider/ProductProvider.dart';
import 'Login.dart';
import 'ProductList.dart';
import 'SectionList.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

List<SectionModel> sectionList = [];
List<Product> catList = [];
List<Product> popularList = [];
ApiBaseHelper apiBaseHelper = ApiBaseHelper();
List<String> tagList = [];
List<Product> sellerList = [];
int count = 1;
List<Model> homeSliderList = [];
List<Widget> pages = [];

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage>, TickerProviderStateMixin {
  bool _isNetworkAvail = true;

  final _controller = PageController();
  late Animation buttonSqueezeanimation;
  late AnimationController buttonController;
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  List<Model> offerImages = [];

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  var db = DatabaseHelper();
  final ScrollController _scrollBottomBarController = ScrollController();
  List<Product> mostFavProList = [];
  List<String> proIds = [];
  List<Product> mostLikeProList = [];
  List<String> proIds1 = [];



  //String? curPin;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    UserProvider user = Provider.of<UserProvider>(context, listen: false);
    SettingProvider setting =
        Provider.of<SettingProvider>(context, listen: false);
    user.setMobile(setting.mobile);
    user.setName(setting.userName);
    user.setEmail(setting.email);
    user.setProfilePic(setting.profileUrl);
    callApi();
    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    buttonSqueezeanimation = Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(
      CurvedAnimation(
        parent: buttonController,
        curve: const Interval(
          0.0,
          0.150,
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _animateSlider());
    Future.delayed(Duration.zero).then((value) {
      hideAppbarAndBottomBarOnScroll(_scrollBottomBarController, context);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isNetworkAvail
            ? RefreshIndicator(
                color: colors.primary,
                key: _refreshIndicatorKey,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  controller: _scrollBottomBarController,
                  slivers: [
                    //_deliverPincode(),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: SearchBarHeaderDelegate(),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _slider(),
                          _showSliderPosition(),
                          _catList(),
                          _section(),
                          _mostLike(),

//                      _seller(),
                        ],
                      ),
                    )
                  ],
                ),
              )
            : noInternet(context),
      ),
    );
  }

  Future<void> _refresh() {
    context.read<HomeProvider>().setCatLoading(true);
    context.read<HomeProvider>().setSecLoading(true);
    context.read<HomeProvider>().setSliderLoading(true);
    context.read<HomeProvider>().setMostLikeLoading(true);
    context.read<HomeProvider>().setOfferLoading(true);
    proIds.clear();

    return callApi();
  }

  Widget _slider() {
    double height = deviceWidth! / 2.2;

    return Selector<HomeProvider, bool>(
      builder: (context, data, child) {
        return data
            ? sliderLoading()
            : homeSliderList.isEmpty
                ? Container()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 15, 10, 0),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: PageView.builder(
                        itemCount: homeSliderList.length,
                        scrollDirection: Axis.horizontal,
                        controller: _controller,
                        physics: const AlwaysScrollableScrollPhysics(),
                        onPageChanged: (index) {
                          context.read<HomeProvider>().setCurSlider(index);
                        },
                        itemBuilder: (BuildContext context, int index) {
                          return pages[index];
                        },
                      ),
                    ),
                  );
      },
      selector: (_, homeProvider) => homeProvider.sliderLoading,
    );
  }

  void _animateSlider() {
    Future.delayed(const Duration(seconds: 1)).then(
      (_) {
        if (mounted) {
          int nextPage = _controller.hasClients
              ? _controller.page!.round() + 1
              : _controller.initialPage;

          if (nextPage == homeSliderList.length) {
            nextPage = 0;
          }
          if (_controller.hasClients) {
            _controller
                .animateToPage(nextPage,
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.linear)
                .then((_) => _animateSlider());
          }
        }
      },
    );
  }

  _singleSection(int index) {
    return sectionList[index].productList!.isNotEmpty
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _getHeading(sectionList[index].title ?? '', index, 1, []),
                    _getSection(index),
                  ],
                ),
              ),
              offerImages.length > index
                  ? Padding(
                      padding:
                          const EdgeInsets.only(top: 20, right: 10, left: 10),
                      child: _getOfferImage(index),
                    )
                  : Container(),
            ],
          )
        : Container();
  }

  _getHeading(
    String title,
    int index,
    int from,
    List<Product> productList,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 15.0, top: 5.0, left: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        //mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (from == 1)
            Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.normal,
                  fontSize: textFontSize16,
                  color: Theme.of(context).colorScheme.fontColor,
                )),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 3,
                child: Text(
                  from == 2 ? title : sectionList[index].shortDesc ?? "",
                  style: const TextStyle(
                    fontSize: textFontSize12,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
              Flexible(
                flex: 1,
                child: GestureDetector(
                  child: Text(
                    getTranslated(context, 'Show All')!,
                    style: Theme.of(context).textTheme.caption!.copyWith(
                          color: Theme.of(context).colorScheme.fontColor,
                          fontSize: textFontSize12,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
                        ),
                  ),
                  onTap: () {
                    SectionModel model = sectionList[index];
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => SectionList(
                          index: index,
                          section_model: model,
                          from: from,
                          productList: productList,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const Divider(thickness: 1),
        ],
      ),
    );
  }

  _getOfferImage(index) {
    return GestureDetector(
      child: FadeInImage(
          fadeInDuration: const Duration(milliseconds: 150),
          image: CachedNetworkImageProvider(offerImages[index].image!),
          width: double.maxFinite,
          imageErrorBuilder: (context, error, stackTrace) => erroWidget(50),

          // errorWidget: (context, url, e) => placeHolder(50),
          placeholder: const AssetImage(
            'assets/images/sliderph.png',
          )),
      onTap: () {
         if (offerImages[index].type == 'products') {
          Product? item = offerImages[index].list;
          print("iteam : ${item!.id} ");
          Navigator.push(
            context,
            PageRouteBuilder(
                //transitionDuration: Duration(seconds: 1),
                pageBuilder: (_, __, ___) =>
                    ProductDetail(model: item, secPos: 0, index: 0, list: true
                        //  title: sectionList[secPos].title,
                        )),
          );
        } else if (offerImages[index].type == 'categories') {
          Product item = offerImages[index].list;
          if (item.subList == null || item.subList!.isEmpty) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => ProductList(
                  name: item.name,
                  id: item.id,
                  tag: false,
                  fromSeller: false,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => SubCategory(
                  title: item.name!,
                  subList: item.subList,
                ),
              ),
            );
          }
        }
      },
    );
  }

  _getSection(int i) {
    var orient = MediaQuery.of(context).orientation;

    return sectionList[i].style == DEFAULT
        ? Padding(
            padding: const EdgeInsets.only(top: 20, right: 10, left: 10),
            child: GridView.count(
              padding: const EdgeInsetsDirectional.only(top: 5),
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 0.750,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,

              //  childAspectRatio: 1.0,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                sectionList[i].productList!.length < 4
                    ? sectionList[i].productList!.length
                    : 4,
                (index) {
                  return productItem(
                      i,
                      index,
                      index % 2 == 0 ? true : false,
                      1,
                      1,
                      sectionList[i].productList![index],
                      1,
                      sectionList[i].productList!.length);
                },
              ),
            ),
          )
        : sectionList[i].style == STYLE1
            ? sectionList[i].productList!.isNotEmpty
                ? Padding(
                    padding:
                        const EdgeInsets.only(top: 20, right: 10, left: 10),
                    child: Row(
                      children: [
                        Flexible(
                            flex: 3,
                            fit: FlexFit.loose,
                            child: SizedBox(
                                height: orient == Orientation.portrait
                                    ? deviceHeight! * 0.6
                                    : deviceHeight!,
                                child: productItem(
                                    i,
                                    0,
                                    true,
                                    5,
                                    2,
                                    sectionList[i].productList![0],
                                    1,
                                    sectionList[i].productList!.length))),
                        Flexible(
                          flex: 2,
                          fit: FlexFit.loose,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    height: orient == Orientation.portrait
                                        ? deviceHeight! * 0.3
                                        : deviceHeight! * 0.6,
                                    child: productItem(
                                        i,
                                        1,
                                        false,
                                        1,
                                        1,
                                        sectionList[i].productList![1],
                                        1,
                                        sectionList[i].productList!.length)),
                                Flexible(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 5.0),
                                    child: SizedBox(
                                        height: orient == Orientation.portrait
                                            ? deviceHeight! * 0.3
                                            : deviceHeight! * 0.6,
                                        child: productItem(
                                            i,
                                            2,
                                            false,
                                            1,
                                            1,
                                            sectionList[i].productList![2],
                                            1,
                                            sectionList[i]
                                                .productList!
                                                .length)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ))
                : Container()
            : sectionList[i].style == STYLE2
                ? Padding(
                    padding:
                        const EdgeInsets.only(top: 20, right: 10, left: 10),
                    child: Row(
                      children: [
                        Flexible(
                          flex: 2,
                          fit: FlexFit.loose,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    height: orient == Orientation.portrait
                                        ? deviceHeight! * 0.3
                                        : deviceHeight! * 0.6,
                                    child: productItem(
                                        i,
                                        1,
                                        false,
                                        1,
                                        1,
                                        sectionList[i].productList![0],
                                        1,
                                        sectionList[i].productList!.length)),
                                Flexible(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 5.0),
                                    child: SizedBox(
                                        height: orient == Orientation.portrait
                                            ? deviceHeight! * 0.3
                                            : deviceHeight! * 0.6,
                                        child: productItem(
                                            i,
                                            2,
                                            false,
                                            1,
                                            1,
                                            sectionList[i].productList![1],
                                            1,
                                            sectionList[i]
                                                .productList!
                                                .length)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Flexible(
                            flex: 3,
                            fit: FlexFit.loose,
                            child: SizedBox(
                                height: orient == Orientation.portrait
                                    ? deviceHeight! * 0.6
                                    : deviceHeight!,
                                child: productItem(
                                    i,
                                    0,
                                    true,
                                    5,
                                    2,
                                    sectionList[i].productList![2],
                                    1,
                                    sectionList[i].productList!.length))),
                      ],
                    ))
                : sectionList[i].style == STYLE3
                    ? Padding(
                        padding:
                            const EdgeInsets.only(top: 20, right: 10, left: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                                flex: 1,
                                fit: FlexFit.loose,
                                child: SizedBox(
                                    height: orient == Orientation.portrait
                                        ? deviceHeight! * 0.3
                                        : deviceHeight! * 0.6,
                                    child: productItem(
                                      i,
                                      0,
                                      false,
                                      3,
                                      2,
                                      sectionList[i].productList![0],
                                      1,
                                      sectionList[i].productList!.length,
                                      true,
                                    ))),
                            SizedBox(
                              height: orient == Orientation.portrait
                                  ? deviceHeight! * 0.3
                                  : deviceHeight! * 0.6,
                              child: Row(
                                children: [
                                  Flexible(
                                      flex: 1,
                                      fit: FlexFit.loose,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            right: 5, top: 5),
                                        child: productItem(
                                          i,
                                          1,
                                          true,
                                          1,
                                          1,
                                          sectionList[i].productList![1],
                                          1,
                                          sectionList[i].productList!.length,
                                        ),
                                      )),
                                  Flexible(
                                      flex: 1,
                                      fit: FlexFit.loose,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            right: 5, top: 5),
                                        child: productItem(
                                          i,
                                          2,
                                          true,
                                          1,
                                          1,
                                          sectionList[i].productList![2],
                                          1,
                                          sectionList[i].productList!.length,
                                        ),
                                      )),
                                  Flexible(
                                      flex: 1,
                                      fit: FlexFit.loose,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: productItem(
                                          i,
                                          3,
                                          false,
                                          1,
                                          1,
                                          sectionList[i].productList![3],
                                          1,
                                          sectionList[i].productList!.length,
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : sectionList[i].style == STYLE4
                        ? Padding(
                            padding: const EdgeInsets.only(
                                top: 20, right: 10, left: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                    flex: 1,
                                    fit: FlexFit.loose,
                                    child: SizedBox(
                                        height: orient == Orientation.portrait
                                            ? deviceHeight! * 0.3
                                            : deviceHeight! * 0.6,
                                        child: productItem(
                                            i,
                                            0,
                                            false,
                                            3,
                                            2,
                                            sectionList[i].productList![0],
                                            1,
                                            sectionList[i].productList!.length,
                                            true))),
                                SizedBox(
                                  height: orient == Orientation.portrait
                                      ? deviceHeight! * 0.3
                                      : deviceHeight! * 0.6,
                                  child: Row(
                                    children: [
                                      Flexible(
                                          flex: 1,
                                          fit: FlexFit.loose,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                right: 5, top: 5),
                                            child: productItem(
                                              i,
                                              1,
                                              true,
                                              1,
                                              1,
                                              sectionList[i].productList![1],
                                              1,
                                              sectionList[i]
                                                  .productList!
                                                  .length,
                                            ),
                                          )),
                                      Flexible(
                                          flex: 1,
                                          fit: FlexFit.loose,
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: productItem(
                                              i,
                                              2,
                                              false,
                                              1,
                                              1,
                                              sectionList[i].productList![2],
                                              1,
                                              sectionList[i]
                                                  .productList!
                                                  .length,
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                              ],
                            ))
                        : Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: GridView.count(
                                padding:
                                    const EdgeInsetsDirectional.only(top: 5),
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                childAspectRatio: 1.2,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 0,
                                crossAxisSpacing: 0,
                                children: List.generate(
                                  sectionList[i].productList!.length < 6
                                      ? sectionList[i].productList!.length
                                      : 6,
                                  (index) {
                                    return productItem(
                                      i,
                                      index,
                                      index % 2 == 0 ? true : false,
                                      1,
                                      1,
                                      sectionList[i].productList![index],
                                      1,
                                      sectionList[i].productList!.length,
                                    );
                                  },
                                )));
  }

  Widget productItem(int secPos, int index, bool pad, int pictureFlex,
      int textFlex, Product product, int from, int len,
      [bool showDiscountAtSameLine = false]) {
    if (len > index) {
      String? offPer;
      double price = double.parse(product.prVarientList![0].disPrice!);
      if (price == 0) {
        price = double.parse(product.prVarientList![0].price!);

        offPer = '0';
      } else {
        double off = double.parse(product.prVarientList![0].price!) - price;
        offPer = ((off * 100) / double.parse(product.prVarientList![0].price!))
            .toStringAsFixed(2);
      }

      double width = deviceWidth! * 0.5;

      Product model = product;

      return Card(
        elevation: 0.0,
        // color: Colors.red,
        // shape: StadiumBorder(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        // shape: BeveledRectangleBorder(

        //   // borderRadius: BorderRadius.only(
        //   //   topLeft: Radius.circular(6),
        //   //   topRight: Radius.circular(6),
        //   //   // bottomLeft: Radius.circular(6),
        //   //   // bottomRight: Radius.circular(6),
        //   // ),
        // ),
        margin: const EdgeInsetsDirectional.only(bottom: 2, end: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: pictureFlex,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Hero(
                        transitionOnUserGestures: true,
                        tag:
                            '$index${sectionList[secPos].productList![index].id}',
                        child: FadeInImage(
                          fadeInDuration: const Duration(milliseconds: 150),
                          image: CachedNetworkImageProvider(
                              sectionList[secPos].productList![index].image!),
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
                  Expanded(
                    flex: textFlex,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 10.0,
                            top: 15,
                          ),
                          child: Text(
                            sectionList[secPos].productList![index].name!,
                            style: Theme.of(context)
                                .textTheme
                                .caption!
                                .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.lightBlack,
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
                            start: 8.0,
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
                              showDiscountAtSameLine
                                  ? Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                          start: 10.0,
                                          top: 5,
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Text(
                                              double.parse(sectionList[secPos]
                                                          .productList![index]
                                                          .prVarientList![0]
                                                          .disPrice!) !=
                                                      0
                                                  ? '${getPriceFormat(context, double.parse(sectionList[secPos].productList![index].prVarientList![0].price!))}'
                                                  : '',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .overline!
                                                  .copyWith(
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    letterSpacing: 0,
                                                    fontSize: textFontSize10,
                                                    fontWeight: FontWeight.w400,
                                                    fontStyle: FontStyle.normal,
                                                  ),
                                            ),
                                            Text(
                                              '  ${double.parse(offPer).round().toStringAsFixed(2)}%',
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
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                        ),
                        double.parse(sectionList[secPos]
                                        .productList![index]
                                        .prVarientList![0]
                                        .disPrice!) !=
                                    0 &&
                                !showDiscountAtSameLine
                            ? Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 10.0,
                                  top: 5,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      double.parse(sectionList[secPos]
                                                  .productList![index]
                                                  .prVarientList![0]
                                                  .disPrice!) !=
                                              0
                                          ? '${getPriceFormat(context, double.parse(sectionList[secPos].productList![index].prVarientList![0].price!))}'
                                          : '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .overline!
                                          .copyWith(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            letterSpacing: 0,
                                            fontSize: textFontSize10,
                                            fontWeight: FontWeight.w400,
                                            fontStyle: FontStyle.normal,
                                          ),
                                    ),
                                    Flexible(
                                      child: Text(
                                          '   ${double.parse(offPer).round().toStringAsFixed(2)}%',
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
                                              )),
                                    ),
                                  ],
                                ),
                              )
                            : Container(),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 10.0,
                            top: 5,
                          ),
                          child:
                              sectionList[secPos].productList![index].rating !=
                                      '0.00'
                                  ? Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          top: 5, bottom: 5),
                                      child: StarRating(
                                          totalRating: sectionList[secPos]
                                              .productList![index]
                                              .rating!,
                                          noOfRatings: sectionList[secPos]
                                              .productList![index]
                                              .noOfRating!,
                                          needToShowNoOfRatings: true),
                                    )
                                  : Container(
                                      height: 5,
                                    ),
                        )
                      ],
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsetsDirectional.only(
                  //     start: 10.0,
                  //     top: 15,
                  //   ),
                  //   child: Text(
                  //     sectionList[secPos].productList![index].name!,
                  //     style: Theme.of(context).textTheme.caption!.copyWith(
                  //           color: Theme.of(context).colorScheme.lightBlack,
                  //           fontSize: textFontSize10,
                  //           fontWeight: FontWeight.w400,
                  //           fontStyle: FontStyle.normal,
                  //         ),
                  //     maxLines: 1,
                  //     overflow: TextOverflow.ellipsis,
                  //   ),
                  // ),
                  // Padding(
                  //   padding: const EdgeInsetsDirectional.only(
                  //     start: 8.0,
                  //     top: 5,
                  //   ),
                  //   child: Row(
                  //     children: [
                  //       Text(
                  //         ' ${getPriceFormat(context, price)!}',
                  //         style: TextStyle(
                  //           color: Theme.of(context).colorScheme.blue,
                  //           fontSize: textFontSize14,
                  //           fontWeight: FontWeight.w700,
                  //           fontStyle: FontStyle.normal,
                  //         ),
                  //       ),
                  //       showDiscountAtSameLine
                  //           ? Expanded(
                  //               child: Padding(
                  //                 padding: const EdgeInsetsDirectional.only(
                  //                   start: 10.0,
                  //                   top: 5,
                  //                 ),
                  //                 child: Row(
                  //                   children: <Widget>[
                  //                     Text(
                  //                       double.parse(sectionList[secPos]
                  //                                   .productList![index]
                  //                                   .prVarientList![0]
                  //                                   .disPrice!) !=
                  //                               0
                  //                           ? '${getPriceFormat(context, double.parse(sectionList[secPos].productList![index].prVarientList![0].price!))}'
                  //                           : '',
                  //                       style: Theme.of(context)
                  //                           .textTheme
                  //                           .overline!
                  //                           .copyWith(
                  //                             decoration:
                  //                                 TextDecoration.lineThrough,
                  //                             letterSpacing: 0,
                  //                             fontSize: textFontSize10,
                  //                             fontWeight: FontWeight.w400,
                  //                             fontStyle: FontStyle.normal,
                  //                           ),
                  //                     ),
                  //                     Text(
                  //                         '  ${double.parse(offPer).round().toStringAsFixed(2)}%',
                  //                         maxLines: 1,
                  //                         overflow: TextOverflow.ellipsis,
                  //                         style: Theme.of(context)
                  //                             .textTheme
                  //                             .overline!
                  //                             .copyWith(
                  //                               color: colors.primary,
                  //                               letterSpacing: 0,
                  //                               fontSize: textFontSize10,
                  //                               fontWeight: FontWeight.w400,
                  //                               fontStyle: FontStyle.normal,
                  //                             )),
                  //                   ],
                  //                 ),
                  //               ),
                  //             )
                  //           : Container(),
                  //     ],
                  //   ),
                  // ),
                  // double.parse(sectionList[secPos]
                  //                 .productList![index]
                  //                 .prVarientList![0]
                  //                 .disPrice!) !=
                  //             0 &&
                  //         !showDiscountAtSameLine
                  //     ? Padding(
                  //         padding: const EdgeInsetsDirectional.only(
                  //           start: 10.0,
                  //           top: 5,
                  //         ),
                  //         child: Row(
                  //           children: <Widget>[
                  //             Text(
                  //               double.parse(sectionList[secPos]
                  //                           .productList![index]
                  //                           .prVarientList![0]
                  //                           .disPrice!) !=
                  //                       0
                  //                   ? '${getPriceFormat(context, double.parse(sectionList[secPos].productList![index].prVarientList![0].price!))}'
                  //                   : '',
                  //               style: Theme.of(context)
                  //                   .textTheme
                  //                   .overline!
                  //                   .copyWith(
                  //                     decoration: TextDecoration.lineThrough,
                  //                     letterSpacing: 0,
                  //                     fontSize: textFontSize10,
                  //                     fontWeight: FontWeight.w400,
                  //                     fontStyle: FontStyle.normal,
                  //                   ),
                  //             ),
                  //             Flexible(
                  //               child: Text(
                  //                   '   ${double.parse(offPer).round().toStringAsFixed(2)}%',
                  //                   maxLines: 1,
                  //                   overflow: TextOverflow.ellipsis,
                  //                   style: Theme.of(context)
                  //                       .textTheme
                  //                       .overline!
                  //                       .copyWith(
                  //                         color: colors.primary,
                  //                         letterSpacing: 0,
                  //                         fontSize: textFontSize10,
                  //                         fontWeight: FontWeight.w400,
                  //                         fontStyle: FontStyle.normal,
                  //                       )),
                  //             ),
                  //           ],
                  //         ),
                  //       )
                  //     : Container(),
                  // Padding(
                  //   padding: const EdgeInsetsDirectional.only(
                  //     start: 10.0,
                  //     top: 5,
                  //   ),
                  //   child:
                  //       sectionList[secPos].productList![index].rating != '0.00'
                  //           ? Padding(
                  //               padding: const EdgeInsetsDirectional.only(
                  //                   top: 5, bottom: 5),
                  //               child: StarRating(
                  //                   totalRating: sectionList[secPos]
                  //                       .productList![index]
                  //                       .rating!,
                  //                   noOfRatings: sectionList[secPos]
                  //                       .productList![index]
                  //                       .noOfRating!,
                  //                   needToShowNoOfRatings: true),
                  //             )
                  //           : Container(
                  //               height: 5,
                  //             ),
                  // )
                ],
              ),
              Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.white,
                          borderRadius: const BorderRadius.only(
                              bottomLeft:
                                  Radius.circular(circularBorderRadius10),
                              topRight: Radius.circular(8))),
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
            Product model = sectionList[secPos].productList![index];
            Navigator.push(
              context,
              PageRouteBuilder(
                // transitionDuration: Duration(milliseconds: 150),
                pageBuilder: (_, __, ___) => ProductDetail(
                    model: model, secPos: secPos, index: index, list: false
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

  Future<void> getMostFavPro() async {
    print("proIds len***${proIds.length}");
    if (proIds1.isNotEmpty) {
      _isNetworkAvail = await isNetworkAvailable();

      if (_isNetworkAvail) {
        try {
          var parameter = {"product_ids": proIds1.join(',')};

          print("paramter*****$parameter");
          apiBaseHelper.postAPICall(getProductApi, parameter).then(
              (getdata) async {
            print("getdata****$getdata");
            bool error = getdata["error"];
            if (!error) {
              var data = getdata["data"];

              List<Product> tempList =
                  (data as List).map((data) => Product.fromJson(data)).toList();
              mostFavProList.clear();
              mostFavProList.addAll(tempList);

              print("most like****${mostLikeProList.length}");

              // context.read<ProductProvider>().setProductList(mostFavProList);
            }
            if (mounted) {
              setState(() {
                context.read<HomeProvider>().setMostLikeLoading(false);
              });
            }
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        } on TimeoutException catch (_) {
          setSnackbar(getTranslated(context, 'somethingMSg')!, context);
          context.read<HomeProvider>().setMostLikeLoading(false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isNetworkAvail = false;
            context.read<HomeProvider>().setMostLikeLoading(false);
          });
        }
      }
    } else {
      context.read<CartProvider>().setCartlist([]);
      setState(() {
        context.read<HomeProvider>().setMostLikeLoading(false);
      });
    }
  }

  Future<void> getMostLikePro() async {
    print("proIds len***${proIds.length}");
    if (proIds.isNotEmpty) {
      _isNetworkAvail = await isNetworkAvailable();

      if (_isNetworkAvail) {
        try {
          var parameter = {"product_ids": proIds.join(',')};

          print("product param****$parameter");
          apiBaseHelper.postAPICall(getProductApi, parameter).then(
              (getdata) async {
            print("getdata****$getdata");
            bool error = getdata["error"];
            if (!error) {
              var data = getdata["data"];

              List<Product> tempList =
                  (data as List).map((data) => Product.fromJson(data)).toList();
              mostLikeProList.clear();
              mostLikeProList.addAll(tempList);

              print("most like****${mostLikeProList.length}");

              context.read<ProductProvider>().setProductList(mostLikeProList);
            }
            if (mounted) {
              setState(() {
                context.read<HomeProvider>().setMostLikeLoading(false);
              });
            }
          }, onError: (error) {
            setSnackbar(error.toString(), context);
          });
        } on TimeoutException catch (_) {
          setSnackbar(getTranslated(context, 'somethingMSg')!, context);
          context.read<HomeProvider>().setMostLikeLoading(false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isNetworkAvail = false;
            context.read<HomeProvider>().setMostLikeLoading(false);
          });
        }
      }
    } else {
      context.read<ProductProvider>().setProductList([]);
      setState(() {
        context.read<HomeProvider>().setMostLikeLoading(false);
      });
    }
  }

  _mostLike() {
    return Selector<HomeProvider, bool>(
      builder: (context, data, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                        margin: const EdgeInsets.only(bottom: 40),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.black26,
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20)))),
                  ),
                  Selector<ProductProvider, List<Product>>(
                    builder: (context, data1, child) {
                      return data1.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _getHeading(
                                      getTranslated(context, "You might also like")!, 0, 2, data1),
                                  Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: GridView.count(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                top: 5),
                                        crossAxisCount: 2,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        children: List.generate(
                                          data1.length < 4 ? data1.length : 4,
                                          (index) {
                                            return productItem(
                                              0,
                                              index,
                                              index % 2 == 0 ? true : false,
                                              1,
                                              1,
                                              data1[index],
                                              2,
                                              data1.length,
                                            );
                                          },
                                        )),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox();
                    },
                    selector: (_, provider) => provider.productList,
                  )
                ],
              ),
            ),
          ],
        );
      },
      selector: (_, homeProvider) => homeProvider.mostLikeLoading,
    );
  }

  _section() {
    return Selector<HomeProvider, bool>(
      builder: (context, data, child) {
        return data || supportedLocale == null
            ? SizedBox(
                width: double.infinity,
                child: Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.simmerBase,
                  highlightColor: Theme.of(context).colorScheme.simmerHigh,
                  child: sectionLoading(),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(0),
                itemCount: sectionList.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return _singleSection(index);
                },
              );
      },
      selector: (_, homeProvider) => homeProvider.secLoading,
    );
  }

  _catList() {
    return Selector<HomeProvider, bool>(
      builder: (context, data, child) {
        return data
            ? SizedBox(
                width: double.infinity,
                child: Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.simmerBase,
                    highlightColor: Theme.of(context).colorScheme.simmerHigh,
                    child: catLoading()))
            : Container(
                height: 100,
                padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
                child: ListView.builder(
                  itemCount: catList.length < 10 ? catList.length : 10,
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container();
                    } else {
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: 18),
                        child: GestureDetector(
                          onTap: () async {
                            if (catList[index].subList == null ||
                                catList[index].subList!.isEmpty) {
                              await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => ProductList(
                                      name: catList[index].name,
                                      id: catList[index].id,
                                      tag: false,
                                      fromSeller: false,
                                    ),
                                  ));
                            } else {
                              await Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => SubCategory(
                                      title: catList[index].name!,
                                      subList: catList[index].subList,
                                    ),
                                  ));
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(25.0),
                                child: FadeInImage(
                                  fadeInDuration:
                                      const Duration(milliseconds: 150),
                                  image: CachedNetworkImageProvider(
                                    catList[index].image!,
                                  ),
                                  height: 50.0,
                                  width: 50.0,
                                  fit: BoxFit.cover,
                                  imageErrorBuilder:
                                      (context, error, stackTrace) =>
                                          erroWidget(50),
                                  placeholder: placeHolder(50),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 50,
                                  child: Text(
                                    catList[index].name!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .caption!
                                        .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .fontColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
      },
      selector: (_, homeProvider) => homeProvider.catLoading,
    );
  }

  List<T> map<T>(List list, Function handler) {
    List<T> result = [];
    for (var i = 0; i < list.length; i++) {
      result.add(handler(i, list[i]));
    }

    return result;
  }

  Future<void> callApi() async {
    UserProvider user = Provider.of<UserProvider>(context, listen: false);
    SettingProvider setting =
        Provider.of<SettingProvider>(context, listen: false);

    user.setUserId(setting.userId);

    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      getSetting();
      getSlider();
      getCat();
      getSeller();
      getSection();
      getOfferImages();
      proIds = (await db.getMostLike())!;
      getMostLikePro();
      proIds1 = (await db.getMostFav())!;
      getMostFavPro();
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
    return;
  }

  Future _getFav() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      if (CUR_USERID != null) {
        Map parameter = {
          USER_ID: CUR_USERID,
        };
        apiBaseHelper.postAPICall(getFavApi, parameter).then((getdata) {
          bool error = getdata['error'];
          String? msg = getdata['message'];
          if (!error) {
            var data = getdata['data'];

            List<Product> tempList =
                (data as List).map((data) => Product.fromJson(data)).toList();

            context.read<FavoriteProvider>().setFavlist(tempList);
          } else {
            if (msg != 'No Favourite(s) Product Are Added') {
              setSnackbar(msg!, context);
            }
          }

          context.read<FavoriteProvider>().setLoading(false);
        }, onError: (error) {
          setSnackbar(error.toString(), context);
          context.read<FavoriteProvider>().setLoading(false);
        });
      } else {
        context.read<FavoriteProvider>().setLoading(false);
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const Login()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  void getOfferImages() {
    Map parameter = {};

    apiBaseHelper.postAPICall(getOfferImageApi, parameter).then((getdata) {
      bool error = getdata['error'];
      String? msg = getdata['message'];
      if (!error) {
        var data = getdata['data'];
        offerImages.clear();
        offerImages =
            (data as List).map((data) => Model.fromSlider(data)).toList();
      } else {
        setSnackbar(msg!, context);
      }

      context.read<HomeProvider>().setOfferLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString(), context);
      context.read<HomeProvider>().setOfferLoading(false);
    });
  }

  void getSection() {
    Map parameter = {PRODUCT_LIMIT: '6', PRODUCT_OFFSET: '0'};

    if (CUR_USERID != null) parameter[USER_ID] = CUR_USERID!;
    String curPin = context.read<UserProvider>().curPincode;
    if (curPin != '') parameter[ZIPCODE] = curPin;

    apiBaseHelper.postAPICall(getSectionApi, parameter).then((getdata) {
      bool error = getdata['error'];
      String? msg = getdata['message'];

      debugPrint('section list is $getdata');
      sectionList.clear();
      if (!error) {
        var data = getdata['data'];

        sectionList =
            (data as List).map((data) => SectionModel.fromJson(data)).toList();
      } else {
        if (curPin != '') context.read<UserProvider>().setPincode('');
        setSnackbar(msg!, context);
      }

      context.read<HomeProvider>().setSecLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString(), context);
      context.read<HomeProvider>().setSecLoading(false);
    });
  }

  void getSetting() {
    CUR_USERID = context.read<SettingProvider>().userId;

    Map parameter = {};
    if (CUR_USERID != null) {
      parameter = {USER_ID: CUR_USERID};
    }

    apiBaseHelper.postAPICall(getSettingApi, parameter).then((getdata) async {
      bool error = getdata['error'];
      String? msg = getdata['message'];

      if (!error) {
        var data = getdata['data']['system_settings'][0];
        supportedLocale = data['supported_locals'];

        cartBtnList = data['cart_btn_on_list'] == '1' ? true : false;
        refer = data['is_refer_earn_on'] == '1' ? true : false;
        CUR_CURRENCY = data['currency'];
        DECIMAL_POINTS = data['decimal_point'];

        RETURN_DAYS = data['max_product_return_days'];
        MAX_ITEMS = data['max_items_cart'];
        MIN_AMT = data['min_amount'];
        CUR_DEL_CHR = data['delivery_charge'];
        Is_APP_IN_MAINTANCE = data['is_customer_app_under_maintenance'];
        MAINTENANCE_MESSAGE = data['message_for_customer_app'];
        String? isVerion = data['is_version_system_on'];
        extendImg = data['expand_product_images'] == '1' ? true : false;
        String? del = data['area_wise_delivery_charge'];
        MIN_ALLOW_CART_AMT = data[MIN_CART_AMT];
        //ALLOW_ATT_MEDIA = data[ALLOW_ATTACH];
        //UP_MEDIA_LIMIT = data[UPLOAD_LIMIT];

        if (del == '0') {
          ISFLAT_DEL = true;
        } else {
          ISFLAT_DEL = false;
        }

        if (Is_APP_IN_MAINTANCE == '1') {
          appMaintenanceDialog();
        }

        if (CUR_USERID != null) {
          REFER_CODE = getdata['data']['user_data'][0]['referral_code'];

          context
              .read<UserProvider>()
              .setPincode(getdata['data']['user_data'][0][PINCODE]);

          if (REFER_CODE == null || REFER_CODE == '' || REFER_CODE!.isEmpty) {
            generateReferral();
          }
          debugPrint(
              "balance i s${getdata['data']['user_data'][0]['balance']}");
          context.read<UserProvider>().setCartCount(
              getdata['data']['user_data'][0]['cart_total_items'].toString());
          context
              .read<UserProvider>()
              .setBalance(getdata['data']['user_data'][0]['balance'] ?? '0');

          _getFav();
          _getCart('0');
          _getOffFav();
          _getOffCart();
        }

        Map<String, dynamic> tempData = getdata['data'];
        if (tempData.containsKey(TAG)) {
          tagList = List<String>.from(getdata['data'][TAG]);
        }

        if (isVerion == '1') {
          String? verionAnd = data['current_version'];
          String? verionIOS = data['current_version_ios'];

          PackageInfo packageInfo = await PackageInfo.fromPlatform();

          String version = packageInfo.version;

          final Version currentVersion = Version.parse(version);
          final Version latestVersionAnd = Version.parse(verionAnd!);
          final Version latestVersionIos = Version.parse(verionIOS!);

          if ((Platform.isAndroid && latestVersionAnd > currentVersion) ||
              (Platform.isIOS && latestVersionIos > currentVersion)) {
            updateDailog();
          }
        }

        setState(() {});
      } else {
        setSnackbar(msg!, context);
      }
    }, onError: (error) {
      setSnackbar(error.toString(), context);
    });
  }

  Future<void> _getOffCart() async {
    if (CUR_USERID == null || CUR_USERID == "") {
      List<String>? proIds = (await db.getCart())!;

      if (proIds.isNotEmpty) {
        _isNetworkAvail = await isNetworkAvailable();

        if (_isNetworkAvail) {
          try {
            var parameter = {"product_variant_ids": proIds.join(',')};
            apiBaseHelper.postAPICall(getProductApi, parameter).then(
                (getdata) async {
              bool error = getdata["error"];
              String? msg = getdata["message"];
              if (!error) {
                var data = getdata["data"];

                List<Product> tempList = (data as List)
                    .map((data) => Product.fromJson(data))
                    .toList();
                List<SectionModel> cartSecList = [];
                for (int i = 0; i < tempList.length; i++) {
                  for (int j = 0; j < tempList[i].prVarientList!.length; j++) {
                    if (proIds.contains(tempList[i].prVarientList![j].id)) {
                      String qty = (await db.checkCartItemExists(
                          tempList[i].id!, tempList[i].prVarientList![j].id!))!;
                      List<Product>? prList = [];
                      prList.add(tempList[i]);
                      cartSecList.add(SectionModel(
                        id: tempList[i].id,
                        varientId: tempList[i].prVarientList![j].id,
                        qty: qty,
                        productList: prList,
                      ));
                    }
                  }
                }

                context.read<CartProvider>().setCartlist(cartSecList);
              }
              if (mounted) {
                setState(() {
                  context.read<CartProvider>().setProgress(false);
                });
              }
            }, onError: (error) {
              setSnackbar(error.toString(), context);
            });
          } on TimeoutException catch (_) {
            setSnackbar(getTranslated(context, 'somethingMSg')!, context);
            context.read<CartProvider>().setProgress(false);
          }
        } else {
          if (mounted) {
            setState(() {
              _isNetworkAvail = false;
              context.read<CartProvider>().setProgress(false);
            });
          }
        }
      } else {
        context.read<CartProvider>().setCartlist([]);
        setState(() {
          context.read<CartProvider>().setProgress(false);
        });
      }
    }
  }

  Future<void> _getOffFav() async {
    if (CUR_USERID == null || CUR_USERID == '') {
      List<String>? proIds = (await db.getFav())!;
      if (proIds.isNotEmpty) {
        _isNetworkAvail = await isNetworkAvailable();

        if (_isNetworkAvail) {
          try {
            var parameter = {'product_ids': proIds.join(',')};

            Response response =
                await post(getProductApi, body: parameter, headers: headers)
                    .timeout(const Duration(seconds: timeOut));

            var getdata = json.decode(response.body);
            bool error = getdata['error'];
            if (!error) {
              var data = getdata['data'];

              List<Product> tempList =
                  (data as List).map((data) => Product.fromJson(data)).toList();

              context.read<FavoriteProvider>().setFavlist(tempList);
            }
            if (mounted) {
              setState(() {
                context.read<FavoriteProvider>().setLoading(false);
              });
            }
          } on TimeoutException catch (_) {
            setSnackbar(getTranslated(context, 'somethingMSg')!, context);
            context.read<FavoriteProvider>().setLoading(false);
          }
        } else {
          if (mounted) {
            setState(() {
              _isNetworkAvail = false;
              context.read<FavoriteProvider>().setLoading(false);
            });
          }
        }
      } else {
        context.read<FavoriteProvider>().setFavlist([]);
        setState(() {
          context.read<FavoriteProvider>().setLoading(false);
        });
      }
    }
  }

  Future<void> _getCart(String save) async {
    _isNetworkAvail = await isNetworkAvailable();

    if (_isNetworkAvail) {
      try {
        var parameter = {USER_ID: CUR_USERID, SAVE_LATER: save};

        Response response =
            await post(getCartApi, body: parameter, headers: headers)
                .timeout(const Duration(seconds: timeOut));

        var getdata = json.decode(response.body);
        bool error = getdata['error'];
        if (!error) {
          var data = getdata['data'];

          List<SectionModel> cartList = (data as List)
              .map((data) => SectionModel.fromCart(data))
              .toList();
          context.read<CartProvider>().setCartlist(cartList);
        }
      } on TimeoutException catch (_) {}
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  final _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  Future<void> generateReferral() async {
    String refer = getRandomString(8);

    //////

    Map parameter = {
      REFERCODE: refer,
    };

    apiBaseHelper.postAPICall(validateReferalApi, parameter).then((getdata) {
      bool error = getdata['error'];
      if (!error) {
        REFER_CODE = refer;

        Map parameter = {
          USER_ID: CUR_USERID,
          REFERCODE: refer,
        };

        apiBaseHelper.postAPICall(getUpdateUserApi, parameter);
      } else {
        if (count < 5) generateReferral();
        count++;
      }

      context.read<HomeProvider>().setSecLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString(), context);
      context.read<HomeProvider>().setSecLoading(false);
    });
  }

  updateDailog() async {
    await dialogAnimate(context,
        StatefulBuilder(builder: (BuildContext context, StateSetter setStater) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5.0))),
        title: Text(getTranslated(context, 'UPDATE_APP')!),
        content: Text(
          getTranslated(context, 'UPDATE_AVAIL')!,
          style: Theme.of(this.context)
              .textTheme
              .subtitle1!
              .copyWith(color: Theme.of(context).colorScheme.fontColor),
        ),
        actions: <Widget>[
          TextButton(
              child: Text(
                getTranslated(context, 'NO')!,
                style: Theme.of(this.context).textTheme.subtitle2!.copyWith(
                    color: Theme.of(context).colorScheme.lightBlack,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              }),
          TextButton(
              child: Text(
                getTranslated(context, 'YES')!,
                style: Theme.of(this.context).textTheme.subtitle2!.copyWith(
                    color: Theme.of(context).colorScheme.fontColor,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.of(context).pop(false);

                String url = '';
                if (Platform.isAndroid) {
                  url = androidLink + packageName;
                } else if (Platform.isIOS) {
                  url = iosLink;
                }

                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),mode: LaunchMode.externalApplication);
                } else {
                  throw 'Could not launch $url';
                }
              })
        ],
      );
    }));
  }

  Widget homeShimmer() {
    return SizedBox(
      width: double.infinity,
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.simmerBase,
        highlightColor: Theme.of(context).colorScheme.simmerHigh,
        child: SingleChildScrollView(
            child: Column(
          children: [
            catLoading(),
            sliderLoading(),
            sectionLoading(),
          ],
        )),
      ),
    );
  }

  Widget sliderLoading() {
    double width = deviceWidth!;
    double height = width / 2;
    return Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.simmerBase,
        highlightColor: Theme.of(context).colorScheme.simmerHigh,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: double.infinity,
          height: height,
          color: Theme.of(context).colorScheme.white,
        ));
  }

  Widget _buildImagePageItem(Model slider) {
    double height = deviceWidth! / 0.5;

    return GestureDetector(
      child: FadeInImage(
          fadeInDuration: const Duration(milliseconds: 150),
          image: CachedNetworkImageProvider(slider.image!),
          height: height,
          //width: double.maxFinite,
          fit: BoxFit.cover,
          imageErrorBuilder: (context, error, stackTrace) => SvgPicture.asset(
                'assets/images/sliderph.svg',
                fit: BoxFit.fill,
                height: height,
                color: colors.primary,
              ),
          placeholderErrorBuilder: (context, error, stackTrace) =>
              SvgPicture.asset(
                'assets/images/sliderph.svg',
                fit: BoxFit.fill,
                height: height,
                color: colors.primary,
              ),
          placeholder: AssetImage('${imagePath}sliderph.png')),
      onTap: () async {
        int curSlider = context.read<HomeProvider>().curSlider;

        if (homeSliderList[curSlider].type == 'products') {
          Product? item = homeSliderList[curSlider].list;

          Navigator.push(
            context,
            PageRouteBuilder(
                pageBuilder: (_, __, ___) => ProductDetail(
                    model: item, secPos: 0, index: 0, list: true)),
          );
        } else if (homeSliderList[curSlider].type == 'categories') {
          Product item = homeSliderList[curSlider].list;
          if (item.subList == null || item.subList!.isEmpty) {
            Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => ProductList(
                    name: item.name,
                    id: item.id,
                    tag: false,
                    fromSeller: false,
                  ),
                ));
          } else {
            Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => SubCategory(
                    title: item.name!,
                    subList: item.subList,
                  ),
                ));
          }
        }
      },
    );
  }

  Widget deliverLoading() {
    return Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.simmerBase,
        highlightColor: Theme.of(context).colorScheme.simmerHigh,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          width: double.infinity,
          height: 18.0,
          color: Theme.of(context).colorScheme.white,
        ));
  }

  Widget catLoading() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
                    .map((_) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.white,
                            shape: BoxShape.circle,
                          ),
                          width: 50.0,
                          height: 50.0,
                        ))
                    .toList()),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          width: double.infinity,
          height: 18.0,
          color: Theme.of(context).colorScheme.white,
        ),
      ],
    );
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
              context.read<HomeProvider>().setCatLoading(true);
              context.read<HomeProvider>().setSecLoading(true);
              context.read<HomeProvider>().setOfferLoading(true);
              context.read<HomeProvider>().setMostLikeLoading(true);
              context.read<HomeProvider>().setSliderLoading(true);
              _playAnimation();

              Future.delayed(const Duration(seconds: 2)).then((_) async {
                _isNetworkAvail = await isNetworkAvailable();
                if (_isNetworkAvail) {
                  if (mounted) {
                    setState(() {
                      _isNetworkAvail = true;
                    });
                  }
                  callApi();
                } else {
                  await buttonController.reverse();
                  if (mounted) setState(() {});
                }
              });
            },
          )
        ]),
      ),
    );
  }

  _deliverPincode() {
    // String curpin = context.read<UserProvider>().curPincode;
    return GestureDetector(
      onTap: _pincodeCheck,
      child: Container(
        // padding: EdgeInsets.symmetric(vertical: 8),
        color: Theme.of(context).colorScheme.white,
        child: ListTile(
          dense: true,
          minLeadingWidth: 10,
          leading: const Icon(
            Icons.location_pin,
          ),
          title: Selector<UserProvider, String>(
            builder: (context, data, child) {
              return Text(
                data == ''
                    ? getTranslated(context, 'SELOC')!
                    : getTranslated(context, 'DELIVERTO')! + data,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.fontColor),
              );
            },
            selector: (_, provider) => provider.curPincode,
          ),
          trailing: const Icon(Icons.keyboard_arrow_right),
        ),
      ),
    );
  }

  void _pincodeCheck() {
    showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        builder: (builder) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9),
              child: ListView(shrinkWrap: true, children: [
                Padding(
                    padding: const EdgeInsets.only(
                        left: 20.0, right: 20, bottom: 40, top: 30),
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Form(
                          key: _formkey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Icon(Icons.close),
                                ),
                              ),
                              TextFormField(
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.words,
                                validator: (val) => validatePincode(val!,
                                    getTranslated(context, 'PIN_REQUIRED')),
                                onSaved: (String? value) {
                                  context
                                      .read<UserProvider>()
                                      .setPincode(value!);
                                },
                                style: Theme.of(context)
                                    .textTheme
                                    .subtitle2!
                                    .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .fontColor),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.location_on),
                                  hintText:
                                      getTranslated(context, 'PINCODEHINT_LBL'),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      margin: const EdgeInsetsDirectional.only(
                                          start: 20),
                                      width: deviceWidth! * 0.35,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          context
                                              .read<UserProvider>()
                                              .setPincode('');

                                          context
                                              .read<HomeProvider>()
                                              .setSecLoading(true);
                                          getSection();
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                            getTranslated(context, 'All')!),
                                      ),
                                    ),
                                    const Spacer(),
                                    SimBtn(
                                        borderRadius: circularBorderRadius5,
                                        size: 0.35,
                                        title: getTranslated(context, 'APPLY'),
                                        onBtnSelected: () async {
                                          if (validateAndSave()) {
                                            // validatePin(curPin);
                                            context
                                                .read<HomeProvider>()
                                                .setSecLoading(true);
                                            getSection();

                                            context
                                                .read<HomeProvider>()
                                                .setSellerLoading(true);
                                            getSeller();

                                            Navigator.pop(context);
                                          }
                                        }),
                                  ],
                                ),
                              ),
                            ],
                          )),
                    ))
              ]),
            );
            //});
          });
        });
  }

  bool validateAndSave() {
    final form = _formkey.currentState!;

    form.save();
    if (form.validate()) {
      return true;
    }
    return false;
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController.forward();
    } on TickerCanceled {}
  }

  void getSlider() {
    Map map = {};

    apiBaseHelper.postAPICall(getSliderApi, map).then((getdata) {
      bool error = getdata['error'];
      String? msg = getdata['message'];
      if (!error) {
        var data = getdata['data'];

        homeSliderList =
            (data as List).map((data) => Model.fromSlider(data)).toList();

        pages = homeSliderList.map((slider) {
          return _buildImagePageItem(slider);
        }).toList();
      } else {
        setSnackbar(msg!, context);
      }

      context.read<HomeProvider>().setSliderLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString(), context);
      context.read<HomeProvider>().setSliderLoading(false);
    });
  }

  void getCat() {
    Map parameter = {
      CAT_FILTER: 'false',
    };
    apiBaseHelper.postAPICall(getCatApi, parameter).then((getdata) {
      bool error = getdata['error'];
      String? msg = getdata['message'];
      if (!error) {
        var data = getdata['data'];

        catList = (data as List).map((data) => Product.fromCat(data)).toList();

        if (getdata.containsKey('popular_categories')) {
          var data = getdata['popular_categories'];
          popularList =
              (data as List).map((data) => Product.fromCat(data)).toList();

          if (popularList.isNotEmpty) {
            Product pop = Product.popular('Popular', '${imagePath}popular.svg');
            catList.insert(0, pop);
            context.read<CategoryProvider>().setSubList(popularList);
          }
        }
      } else {
        setSnackbar(msg!, context);
      }

      context.read<HomeProvider>().setCatLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString(), context);
      context.read<HomeProvider>().setCatLoading(false);
    });
  }

  sectionLoading() {
    return Column(
        children: [0, 1, 2, 3, 4]
            .map((_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 40),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 5),
                                width: double.infinity,
                                height: 18.0,
                                color: Theme.of(context).colorScheme.white,
                              ),
                              GridView.count(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                childAspectRatio: 1.0,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 5,
                                crossAxisSpacing: 5,
                                children: List.generate(
                                  6,
                                  (index) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color:
                                          Theme.of(context).colorScheme.white,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    sliderLoading()
                    //offerImages.length > index ? _getOfferImage(index) : Container(),
                  ],
                ))
            .toList());
  }

  void getSeller() {
    String pin = context.read<UserProvider>().curPincode;
    Map parameter = {};
    if (pin != '') {
      parameter = {
        ZIPCODE: pin,
      };
    }
    apiBaseHelper.postAPICall(getSellerApi, parameter).then((getdata) {
      bool error = getdata['error'];
      String? msg = getdata['message'];
      if (!error) {
        var data = getdata['data'];

        sellerList =
            (data as List).map((data) => Product.fromSeller(data)).toList();
      } else {
        setSnackbar(msg!, context);
      }

      context.read<HomeProvider>().setSellerLoading(false);
    }, onError: (error) {
      setSnackbar(error.toString(), context);
      context.read<HomeProvider>().setSellerLoading(false);
    });
  }

  _seller() {
    return Selector<HomeProvider, bool>(
      builder: (context, data, child) {
        return data
            ? SizedBox(
                width: double.infinity,
                child: Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.simmerBase,
                    highlightColor: Theme.of(context).colorScheme.simmerHigh,
                    child: catLoading()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 10.0, top: 10.0, right: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(getTranslated(context, 'SHOP_BY_SELLER')!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.fontColor,
                                fontWeight: FontWeight.bold)),
                        TextButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (context) =>
                                          const SellerList()));
                            },
                            child: Text(getTranslated(context, 'VIEW_ALL')!))
                      ],
                    ),
                  ),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.only(top: 10, left: 10),
                    child: ListView.builder(
                      itemCount: sellerList.length,
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (context) => SellerProfile(
                                            sellerStoreName:
                                                sellerList[index].store_name ??
                                                    '',
                                            sellerRating: sellerList[index]
                                                    .seller_rating ??
                                                '',
                                            sellerImage: sellerList[index]
                                                    .seller_profile ??
                                                '',
                                            sellerName:
                                                sellerList[index].seller_name ??
                                                    '',
                                            sellerID:
                                                sellerList[index].seller_id,
                                            storeDesc: sellerList[index]
                                                .store_description,
                                          )));
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      bottom: 5.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                        child: FadeInImage(
                                          fadeInDuration:
                                              const Duration(milliseconds: 150),
                                          image: CachedNetworkImageProvider(
                                            sellerList[index].seller_profile!,
                                          ),
                                          height: 130.0,
                                          width: 100.0,
                                          fit: BoxFit.cover,
                                          imageErrorBuilder:
                                              (context, error, stackTrace) =>
                                                  erroWidget(50),
                                          placeholder: placeHolder(50),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 2,
                                        child: Container(
                                          width: 100,
                                          color: colors.white10,
                                          child: Column(
                                            children: [
                                              Text(
                                                sellerList[index].seller_name!,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    color: colors.primary),
                                                textAlign: TextAlign.start,
                                              ),
                                              RatingBarIndicator(
                                                rating: double.parse(
                                                    sellerList[index]
                                                        .seller_rating!),
                                                itemBuilder: (context, index) =>
                                                    const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                ),
                                                itemCount: 5,
                                                itemSize: 12.0,
                                                direction: Axis.horizontal,
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                /* Container(
                                  child: Text(
                                    sellerList[index].seller_name!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .caption!
                                        .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .fontColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  width: 50,
                                ),*/
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
      },
      selector: (_, homeProvider) => homeProvider.sellerLoading,
    );
  }

  void appMaintenanceDialog() async {
    await dialogAnimate(context,
        StatefulBuilder(builder: (BuildContext context, StateSetter setStater) {
      return WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: AlertDialog(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5.0))),
          title: Text(
            getTranslated(context, 'APP_MAINTENANCE')!,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.fontColor,
                fontWeight: FontWeight.normal,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                child: Lottie.asset('assets/animation/app_maintenance.json'),
              ),
              const SizedBox(
                height: 25,
              ),
              Text(
                MAINTENANCE_MESSAGE != ''
                    ? '$MAINTENANCE_MESSAGE'
                    : getTranslated(context, 'MAINTENANCE_DEFAULT_MESSAGE')!,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.fontColor,
                    fontWeight: FontWeight.normal,
                    fontSize: 12),
              )
            ],
          ),
        ),
      );
    }));
  }

  _showSliderPosition() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: map<Widget>(
          homeSliderList,
          (index, url) {
            return Selector<HomeProvider, int>(
              builder: (context, curSliderIndex, child) {
                return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: curSliderIndex == index ? 25 : 8.0,
                    height: 5.0,
                    margin: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 2.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5.0),
                      color: curSliderIndex == index
                          ? Theme.of(context).colorScheme.fontColor
                          : Theme.of(context)
                              .colorScheme
                              .lightBlack
                              .withOpacity(0.7),
                    ));
              },
              selector: (_, slider) => slider.curSlider,
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollBottomBarController.removeListener(() {});
    super.dispose();
  }

  _setFav(int index, Product model) async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      try {
        if (mounted) {
          setState(() {
            index == -1 ? model.isFavLoading = true : model.isFavLoading = true;
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
          index == -1 ? model.isFav = '1' : model.isFav = '1';

          context.read<FavoriteProvider>().addFavItem(model);
        } else {
          setSnackbar(msg!, context);
        }

        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = false
                : model.isFavLoading = false;
          });
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
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
            index == -1 ? model.isFavLoading = true : model.isFavLoading = true;
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
          index == -1 ? model.isFav = '0' : model.isFav = '0';
          context
              .read<FavoriteProvider>()
              .removeFavItem(model.prVarientList![0].id!);
        } else {
          setSnackbar(msg!, context);
        }

        if (mounted) {
          setState(() {
            index == -1
                ? model.isFavLoading = false
                : model.isFavLoading = false;
          });
        }
      } on TimeoutException catch (_) {
        setSnackbar(getTranslated(context, 'somethingMSg')!, context);
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

class SearchBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.lightWhite,
      //data == Brightness.light ?Color(0xffEEF2F9) :  Color(0xff181616),
      padding: const EdgeInsets.fromLTRB(10, 35, 10, 0),
      child: GestureDetector(
        child: SizedBox(
          height: 80,
          child: TextField(
            enabled: false,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.lightWhite),
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
                contentPadding: const EdgeInsets.fromLTRB(15.0, 5.0, 0, 5.0),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.all(
                    Radius.circular(10.0),
                  ),
                ),
                isDense: true,
                hintText: getTranslated(context, 'searchHint'),
                hintStyle: Theme.of(context).textTheme.bodyText2!.copyWith(
                      color: Theme.of(context).colorScheme.fontColor,
                      fontSize: textFontSize12,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                    ),
                prefixIcon:  Padding(
                    padding: EdgeInsets.all(15.0),
                    child: SvgPicture.asset(
                      '${imagePath}homepage_search.svg',
                      height: 15,
                      width: 15,
                    )),
                suffixIcon: Selector<ThemeNotifier, ThemeMode>(
                    selector: (_, themeProvider) =>
                        themeProvider.getThemeMode(),
                    builder: (context, data, child) {
                      return Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: (data == ThemeMode.system &&
                                    MediaQuery.of(context).platformBrightness ==
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
                              ),
                      );
                    }),
                fillColor: Theme.of(context).colorScheme.white,
                filled: true),
          ),
        ),
        onTap: () async {
          //showOverlaySnackBar(context, Colors.amber, "message",50 );
          await Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const Search(),
              ));
        },
      ),
    );
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
