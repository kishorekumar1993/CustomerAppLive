import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'Color.dart';

class SimBtn extends StatelessWidget {
  final String? title;
  final VoidCallback? onBtnSelected;
  double? size;
  double? height;
  Color? backgroundColor,borderColor,titleFontColor;
  double? borderWidth,borderRadius;

  SimBtn({
    Key? key,
    this.title,
    this.onBtnSelected,
    this.size,
    this.height,
    this.titleFontColor,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size.width * size!;
    return _buildBtnAnimation(context);
  }

  Widget _buildBtnAnimation(BuildContext context) {
    return CupertinoButton(
      child: Container(
          width: size,
          height: height ?? 35,
          alignment: FractionalOffset.center,
          decoration: BoxDecoration(
              color: backgroundColor ?? colors.primary,
              borderRadius:  BorderRadius.all(Radius.circular(borderRadius ?? 0.0)),
              border: Border.all(
                  width: borderWidth ?? 0,
                  color: borderColor ?? Colors.transparent)),
          child: Text(title!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.subtitle1!.copyWith(
                  color: titleFontColor ?? colors.whiteTemp, fontWeight: FontWeight.normal))),

      onPressed: () {
        onBtnSelected!();
      },
    );
  }
}
