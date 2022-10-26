import 'package:eshop_multivendor/Helper/String.dart';
import 'package:intl/intl.dart';

class FaqsModel {
  String? id, question, answer, status, uname, ansBy, dateAdded;

  FaqsModel(
      {this.id,
      this.question,
      this.answer,
      this.status,
      this.uname,
      this.dateAdded,
      this.ansBy});

  factory FaqsModel.fromJson(Map<String, dynamic> json) {
    String date = json["date_added"];
    // date = DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
    date = DateFormat.yMMMMd().format(DateTime.parse(date));
    return FaqsModel(
      id: json[ID],
      question: json[QUESTION],
      answer: json[ANSWER],
      status: json[STATUS],
      uname: json[USERNAME],
      dateAdded: date,
      ansBy: json["answered_by_name"],
    );
  }

  factory FaqsModel.fromProfileFaq(Map<String, dynamic> json) {
    // String date = json["date_added"];
    // date = DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
    // date = DateFormat.yMMMMd().format(DateTime.parse(date));
    return FaqsModel(
      id: json[ID],
      question: json[QUESTION],
      answer: json[ANSWER],
      status: json[STATUS],
     
    );
  }
}
