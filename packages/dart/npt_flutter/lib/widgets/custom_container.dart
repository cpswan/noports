import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';

import '../styles/sizes.dart';

class CustomContainer extends StatelessWidget {
  const CustomContainer({
    required this.child,
    required this.color,
    required this.padding,
    required this.width,
    super.key,
  });

  const CustomContainer.background({required this.child, this.width, super.key})
      : color = AppColor.surfaceColor,
        padding = Sizes.p16;

  const CustomContainer.foreground({required this.child, this.width, super.key, this.padding = 0})
      : color = Colors.white;

  final Widget child;
  final Color color;
  final double padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: child,
    );
  }
}
