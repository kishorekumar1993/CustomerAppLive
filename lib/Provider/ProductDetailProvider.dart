import 'package:eshop_multivendor/Model/Section_Model.dart';
import 'package:flutter/cupertino.dart';

class ProductDetailProvider extends ChangeNotifier {
  final bool _reviewLoading = true;
  bool _moreProductLoading = true;
  bool _listType = false;
  bool _saleSectionlistType = false;
  bool _sectionlistType = false;

  final List<Product> _compareList = [];

  get compareList => _compareList;

  get listType => _listType;
  get saleSectionListType => _saleSectionlistType;
  get sectionListType => _sectionlistType;

  get moreProductLoading => _moreProductLoading;

  get reviewLoading => _reviewLoading;
  ///-----------
  int _offset = 0;
  get offset => _offset;

  bool _moreProNotiLoading = true;

  get moreProNotiLoading => _moreProNotiLoading;

  setProNotiLoading(bool loading) {
    _moreProNotiLoading = loading;
    notifyListeners();
  }

  int _total = 0;

  get total => _total;

  setProTotal(int total) {
    _total = total;
    notifyListeners();
  }
  List<Product> _productList = [];


  setProductList(List<Product>? productList) {
    _productList = productList!;
    notifyListeners();
  }


  setProOffset(int offset) {
    _offset = offset;
    notifyListeners();
  }
  /// --------------
  setReviewLoading(bool loading) {
    _moreProductLoading = loading;
    notifyListeners();
  }

  setListType(bool listType) {
    _listType = listType;
    notifyListeners();
  }
  setSectionListType(bool listType) {
    _sectionlistType = listType;
    notifyListeners();
  }

  setSaleSectionListType(bool listType) {
    _saleSectionlistType = listType;
    notifyListeners();
  }

  setProductLoading(bool loading) {
    _moreProductLoading = loading;
    notifyListeners();
  }

  addCompareList(Product compareList) {
    _compareList.add(compareList);
    notifyListeners();
  }
}
