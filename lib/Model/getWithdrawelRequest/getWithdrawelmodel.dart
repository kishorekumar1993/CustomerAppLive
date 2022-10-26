import 'package:intl/intl.dart';

import '../../Helper/String.dart';

class GetWithdrawelReq {
  String? id,
      userId,
      paymentType,
      paymentAddress,
      amountRequested,
      remarks,
      status,
      dateCreated;

  GetWithdrawelReq({
    this.id,
    this.userId,
    this.paymentType,
    this.paymentAddress,
    this.amountRequested,
    this.remarks,
    this.status,
    this.dateCreated,
  });
  factory GetWithdrawelReq.fromJson(Map<String, dynamic> json) {
    return GetWithdrawelReq(
      id: json[ID],
      userId: json[USER_ID],
      paymentType: json[PAYMERNT_TYPE],
      paymentAddress: json[PAYMENT_ADD],
      amountRequested: json[AMOUNT_REQUEST],
      remarks: json[Remark],
      status: json[STATUS],
      dateCreated: json[DATE_CREATED],
    );
  }
  factory GetWithdrawelReq.fromReqJson(Map<String, dynamic> json) {
    String date = json[DATE_CREATED];

    date = DateFormat('dd-MM-yyyy').format(
      DateTime.parse(date),
    );
    String? st = json[STATUS];
    if (st == "0") {
      st = PENDINg;
    } else if (st == "1") {
      st = ACCEPTEd;
    } else if (st == "2") {
      st = REJECTEd;
    }
    return GetWithdrawelReq(
      id: json[ID],
      amountRequested: json[AMOUNT_REQUEST],
      status: st,
      dateCreated: date,
      userId: json[USER_ID],
      paymentType: json[PAYMERNT_TYPE],
      paymentAddress: json[PAYMENT_ADD],
      remarks: json[Remark],
    );
  }
}
