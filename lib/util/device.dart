import 'package:flutter_control/core.dart';

class Device {
  final MediaQueryData data;
  final BuildContext context;

  const Device(this.data, [this.context]);

  factory Device.of(BuildContext context) => Device(MediaQuery.of(context), context);

  bool get portrait => data.orientation == Orientation.portrait;

  bool get landscape => data.orientation == Orientation.landscape;

  Size get size => data.size;

  double get width => size.width;

  double get height => size.height;

  double get ratio => 1.0 / data.devicePixelRatio;

  @deprecated
  bool get hasNotch => data.padding.top > 20.0;

  double get topBorderSize => data.padding.top;

  double get bottomBorderSize => data.padding.bottom;

  double px(double value) => value * ratio;

  double dp(double value) => value / ratio;

  Size pxSize(Size size) => Size(px(size.width), px(size.height));

  Size dpSize(Size size) => Size(dp(size.width), dp(size.height));

  Offset pxOffset(Offset offset) => Offset(px(offset.dx), px(offset.dy));

  Offset dpOffset(Offset offset) => Offset(dp(offset.dx), dp(offset.dy));

  T onOrientation<T>(Getter<T> portrait, Getter<T> landscape) {
    if (this.portrait) {
      return portrait();
    }

    return landscape();
  }
}
