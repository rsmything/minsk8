import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:minsk8/import.dart';

class ZoomScreen extends StatefulWidget {
  final ZoomRouteArguments arguments;

  ZoomScreen(this.arguments);

  @override
  _ZoomScreenState createState() {
    return _ZoomScreenState();
  }
}

class _ZoomScreenState extends State<ZoomScreen>
    with SingleTickerProviderStateMixin {
  AnimationController _animationController;
  Animation<double> _animation;
  Function animationListener;
  List<double> doubleTapScales = <double>[1.0, 2.0];
  int _currentIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 150), vsync: this);
    _currentIndex = widget.arguments.index;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.arguments.item;
    final tag = widget.arguments.tag;
    final size = MediaQuery.of(context).size;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: tag,
              child: ExtendedImage.network(
                item.images[_currentIndex].getLargeDummyUrl(item.id),
                fit: BoxFit.contain,
                loadStateChanged: loadStateChanged,
                //enableLoadState: false,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (state) {
                  double initialScale = 1.0;
                  if (state.extendedImageInfo != null &&
                      state.extendedImageInfo.image != null) {
                    initialScale = initScale(
                        size: size,
                        initialScale: initialScale,
                        imageSize: Size(
                            state.extendedImageInfo.image.width.toDouble(),
                            state.extendedImageInfo.image.height.toDouble()));
                  }
                  return GestureConfig(
                    minScale: 0.9,
                    animationMinScale: 0.7,
                    maxScale: 4.0,
                    animationMaxScale: 4.5,
                    speed: 1.0,
                    inertialSpeed: 100.0,
                    initialScale: initialScale,
                    inPageView: false,
                    initialAlignment: InitialAlignment.center,
                  );
                },
                onDoubleTap: (ExtendedImageGestureState state) {
                  ///you can use define pointerDownPosition as you can,
                  ///default value is double tap pointer down position.
                  final pointerDownPosition = state.pointerDownPosition;
                  double begin = state.gestureDetails.totalScale;
                  double end;
                  //remove old
                  _animation?.removeListener(animationListener);
                  //stop pre
                  _animationController.stop();
                  //reset to use
                  _animationController.reset();
                  if (begin == doubleTapScales[0]) {
                    end = doubleTapScales[1];
                  } else {
                    end = doubleTapScales[0];
                  }
                  animationListener = () {
                    state.handleDoubleTap(
                        scale: _animation.value,
                        doubleTapPosition: pointerDownPosition);
                  };
                  _animation = _animationController
                      .drive(Tween<double>(begin: begin, end: end));
                  _animation.addListener(animationListener);
                  _animationController.forward();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    widget.arguments.onWillPop(_currentIndex);
    return true;
  }
}

class ZoomRouteArguments {
  final ItemModel item;
  final String tag;
  final int index;
  final Function onWillPop;

  ZoomRouteArguments(this.item, {this.tag, this.index, this.onWillPop});
}

double initScale({Size imageSize, Size size, double initialScale}) {
  var n1 = imageSize.height / imageSize.width;
  var n2 = size.height / size.width;
  if (n1 > n2) {
    final FittedSizes fittedSizes =
        applyBoxFit(BoxFit.contain, imageSize, size);
    //final Size sourceSize = fittedSizes.source;
    Size destinationSize = fittedSizes.destination;
    return size.width / destinationSize.width;
  } else if (n1 / n2 < 1 / 4) {
    final FittedSizes fittedSizes =
        applyBoxFit(BoxFit.contain, imageSize, size);
    //final Size sourceSize = fittedSizes.source;
    Size destinationSize = fittedSizes.destination;
    return size.height / destinationSize.height;
  }
  return initialScale;
}
