import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum PullRefreshState {
  pull, // 下拉过程
  wait, // 拉到刷新位置等待释放
  Refresh, // 释放刷新
  nextPage, // 翻页加载
  not, // 未操作/刷新/加载完毕
}

enum PullWidgetId { Indicator, ListView, footerIndicator }

abstract class HtRefreshCallback {
  Future<dynamic> refresh() async {}
  Future<dynamic> nextPage() async {}
  void cancel() {}
}

typedef RefreshPullCalback = Function(double, PullRefreshState);
typedef Widget RefresherIndicatorWidget(
    double pixels, PullRefreshState refreshState);

// RefreshListWidget(
//     onRefresh: HomeRefreshCallback(),
//     refreshWidget: (double pixels, PullRefreshState refreshState) {
//       return MyRefreshIndicator(pixels: pixels, refreshState: refreshState, height: 95.0 + 95.0,);
//     },
//     indicatorHeight: 95.0,
//     expandHeight: 95.0,
//     scrollController: scrollController,
//     isMore: false,
//     moreCallback: (){
//       print("更多操作");
//     },
//     child: new StaggeredGridView.countBuilder(
//       physics: BouncingScrollPhysics(),
//       controller: scrollController,
//       primary: false,
//       crossAxisCount: 2,
//       crossAxisSpacing: 4.0,
//       mainAxisSpacing: 4.0,
//       itemBuilder: _getChild,
//       itemCount: 3000,
//       padding: EdgeInsets.only(top: 95.0),
//       staggeredTileBuilder: (int index) => StaggeredTile.fit(1),
//     ),
//   )

class RefreshListWidget extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;
  final RefresherIndicatorWidget refreshWidget;
  final RefresherIndicatorWidget nextWidget;
  final HtRefreshCallback onRefresh;
  final bool isMore;
  final VoidCallback moreCallback;
  RefreshPullCalback refresherPull;

  final double indicatorHeight;
  final double nextWidgetHeight;
  final double expandHeight;
  final double refreshOffset;
  final double nextOffset; // 屏幕百分比

  RefreshListWidget({
    Key key,
    this.scrollController,
    this.child,
    this.refreshWidget,
    this.refreshOffset = 80.0,
    this.indicatorHeight = 0.0,
    this.onRefresh,
    this.isMore = false,
    this.moreCallback,
    this.expandHeight = 0.0,
    this.refresherPull,
    this.nextOffset = 1.0,
    this.nextWidget,
    this.nextWidgetHeight = 0.0,
  }) : super(key: key) {
    if (refresherPull == null) {
      refresherPull = (double p, PullRefreshState state) {};
    }
  }
  @override
  _RefreshListWidgetState createState() => _RefreshListWidgetState();
}

class _RefreshListWidgetState extends State<RefreshListWidget> {
  bool _isRefresh = false;
  bool _isLoading = false;
  bool _toMore = false;
  bool _nextload = false;
  // bool _isAnim = false;
  double _pixels = 0.0;
  double _overstepOffset = 0.0;
  PullRefreshState _refreshState = PullRefreshState.not;

  @override
  void initState(){
    super.initState();
  }

  double __startOffset = 0.0;
  bool _onScroll(Notification notification) {
    if (notification is ScrollUpdateNotification) {
      double pixels = notification.metrics.pixels;
      double of = pixels - notification.metrics.maxScrollExtent;
      setState(() {
        _pixels = _getPullPixelsOf(pixels);
        _overstepOffset = of > 0.0 ? of : 0.0;
      });
      if (notification.dragDetails == null) {
        if (pixels <= 0) {
          if (_isRefresh == true) {
            if (_getPullPixelsOf(pixels) < widget.refreshOffset * 0.6) {
              widget.onRefresh.cancel();
              _isRefresh = false;
              _isLoading = false;
              if (_refreshState != PullRefreshState.not) {
                setState(() {
                  _refreshState = PullRefreshState.not;
                });
              }
              widget.refresherPull(_pixels, _refreshState);
              return false;
            }
            widget.scrollController.jumpTo(-widget.refreshOffset);
            // if (_isAnim) {
            //   widget.scrollController
            //       .animateTo(-widget.refreshOffset,
            //           duration: Duration(milliseconds: 300), curve: Curves.ease)
            //       .whenComplete(() {
            //         _isAnim = false;
            //       });
            // } else {
            //   widget.scrollController.jumpTo(-widget.refreshOffset);
            // }
            setState(() {
              _refreshState = PullRefreshState.Refresh;
            });
            if (_isLoading == false) {
              _isLoading = true;

              widget.onRefresh.refresh().whenComplete(() {
                _isRefresh = false;
                _isLoading = false;
                setState(() {
                  _refreshState = PullRefreshState.not;
                });
              });
            }
          } else {
            // 下拉结束的偏移小于 refreshOffset 不触发刷新动作
            if (_getPullPixelsOf(pixels) >= widget.refreshOffset) {
              if (widget.isMore &&
                  _toMore == false &&
                  _getPullPixelsOf(pixels) >= widget.refreshOffset * 1.5) {
                _toMore = true;
                widget.moreCallback();
                return false;
              }
              if (_toMore == false && _isRefresh == false) {
                // _isAnim = true;
                _isRefresh = true;
              }
            } else {
              _isRefresh = false;
              if (_refreshState != PullRefreshState.not) {
                setState(() {
                  _refreshState = PullRefreshState.not;
                });
              }
            }
          }
        }
      } else {
        if (pixels <= 0) {
          if (_getPullPixelsOf(pixels) >= widget.refreshOffset) {
            if (_refreshState != PullRefreshState.wait) {
              setState(() {
                _refreshState = PullRefreshState.wait;
              });
            }
          } else {
            if (_refreshState != PullRefreshState.pull) {
              setState(() {
                _refreshState = PullRefreshState.pull;
              });
            }
          }
        } else {
          if (notification.metrics.extentAfter <
                  notification.metrics.extentInside * widget.nextOffset &&
              _nextload == false &&
                  widget.onRefresh.nextPage != null) {
            setState(() {
              _nextload = true;
              _refreshState = PullRefreshState.nextPage;
            });
            widget.onRefresh.nextPage().whenComplete(() {
              setState(() {
                _nextload = false;
                _refreshState = PullRefreshState.not;
              });
            });
          }
        }
      }
    } else if (notification is UserScrollNotification) {
      _toMore = false;
      double pixels = notification.metrics.pixels;
      if (widget.expandHeight > 0 &&
          pixels > 0 &&
          pixels < widget.expandHeight) {
        if (notification.metrics.pixels - __startOffset > 0) {
          widget.scrollController.animateTo(widget.expandHeight,
              duration: Duration(milliseconds: 200), curve: Curves.ease);
        } else if (notification.metrics.pixels - __startOffset < 0) {
          widget.scrollController.animateTo(0.0,
              duration: Duration(milliseconds: 200), curve: Curves.ease);
        }
      }
    } else if (notification is ScrollStartNotification) {
      __startOffset = notification.metrics.pixels;
    }
    widget.refresherPull(_pixels, _refreshState);
    return false;
  }

  double _getPullPixelsOf(double v) {
    return -v;
  }

  @override
  Widget build(BuildContext context) {
    return MyRefreshContainer(
      indicatorHeight: widget.indicatorHeight,
      listView: NotificationListener(
        child: widget.child,
        onNotification: _onScroll,
      ),
      footerIndicator: widget.nextWidget != null ? Stack(
        overflow: Overflow.visible,
        children: <Widget>[
          Positioned(
            width: MediaQuery.of(context).size.width,
            height: widget.nextWidgetHeight,
            child: widget.nextWidget(_pixels, _refreshState),
            top: 12.0 - _overstepOffset,
          )
        ],
      ) : null,
      indicator: Stack(children: [
        Positioned(
            top: widget.expandHeight > 0
                ? _pixels <= -widget.expandHeight
                    ? -widget.expandHeight
                    : _pixels >= 0 ? 0.0 : _pixels
                : 0.0,
            child: widget.refreshWidget(_pixels, _refreshState))
      ]),
    );
  }
}

class MyRefreshContainer extends StatelessWidget {
  final Widget listView;
  final Widget indicator;
  final Widget footerIndicator;
  final double indicatorHeight;
  final double nextWidgetHeight;

  MyRefreshContainer(
      {Key key, this.listView, this.indicator, this.indicatorHeight, this.footerIndicator, this.nextWidgetHeight = 0.0})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> _children = [];

    _children.add(LayoutId(
      id: PullWidgetId.ListView,
      child: listView,
    ));

    if (indicator != null) {
      _children.add(LayoutId(
        id: PullWidgetId.Indicator,
        child: indicator,
      ));
    }


    if (footerIndicator != null) {
      _children.add(LayoutId(
        id: PullWidgetId.footerIndicator,
        child: footerIndicator,
      ));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width,
          maxHeight: MediaQuery.of(context).size.height),
      child: CustomMultiChildLayout(
        delegate:
            _MyRefreshContainerLayoutDelegate(context, indicatorHeight: indicatorHeight, nextWidgetHeight: nextWidgetHeight),
        children: _children,
      ),
    );
  }
}

class _MyRefreshContainerLayoutDelegate extends MultiChildLayoutDelegate {
  final double indicatorHeight;
  final double nextWidgetHeight;
  final BuildContext context;

  _MyRefreshContainerLayoutDelegate(this.context, {this.indicatorHeight, this.nextWidgetHeight = 0.0});

  @override
  void performLayout(Size size) {
    if (hasChild(PullWidgetId.Indicator)) {
      layoutChild(PullWidgetId.Indicator, BoxConstraints.tight(size));
      positionChild(PullWidgetId.Indicator, Offset(0.0, 0.0));
    }

    if (hasChild(PullWidgetId.ListView)) {
      layoutChild(PullWidgetId.ListView, BoxConstraints.tight(size));
      positionChild(PullWidgetId.ListView, Offset(0.0, indicatorHeight));
    }

    if (hasChild(PullWidgetId.footerIndicator)) {
      layoutChild(PullWidgetId.footerIndicator, BoxConstraints.loose(size));
      positionChild(PullWidgetId.footerIndicator, Offset(0.0, size.height - MediaQuery.of(context).padding.bottom));
    }
  }

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => false;
}

const double _kDefaultIndicatorRadius = 10.0;

/// An iOS-style activity indicator.
///
/// See also:
///
///  * <https://developer.apple.com/ios/human-interface-guidelines/controls/progress-indicators/#activity-indicators>
class HtRefreshIndicator extends StatefulWidget {
  /// Creates an iOS-style activity indicator.
  const HtRefreshIndicator({
    Key key,
    this.animating: true,
    this.radius: _kDefaultIndicatorRadius,
  })  : assert(animating != null),
        assert(radius != null),
        assert(radius > 0),
        super(key: key);

  /// Whether the activity indicator is running its animation.
  ///
  /// Defaults to true.
  final bool animating;

  /// Radius of the spinner widget.
  ///
  /// Defaults to 10px. Must be positive and cannot be null.
  final double radius;

  @override
  _HtRefreshIndicatorState createState() => new _HtRefreshIndicatorState();
}

class _HtRefreshIndicatorState extends State<HtRefreshIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = new AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(HtRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating != oldWidget.animating) {
      if (widget.animating)
        _controller.repeat();
      else
        _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new SizedBox(
      height: widget.radius * 2,
      width: widget.radius * 2,
      child: new CustomPaint(
        painter: new _HtRefreshIndicatorPainter(
          position: _controller,
          radius: widget.radius,
        ),
      ),
    );
  }
}

const double _kTwoPI = math.pi * 2.0;
const int _kTickCount = 12;
const int _kHalfTickCount = _kTickCount ~/ 2;
const Color _kTickColor = const Color(0xFFE5E5EA);
const Color _kActiveTickColor = const Color(0xFF9D9D9D);

class _HtRefreshIndicatorPainter extends CustomPainter {
  _HtRefreshIndicatorPainter({
    this.position,
    double radius,
  })  : tickFundamentalRRect = new RRect.fromLTRBXY(
            -radius,
            1.0 * radius / _kDefaultIndicatorRadius,
            -radius / 2.0,
            -1.0 * radius / _kDefaultIndicatorRadius,
            1.0,
            1.0),
        super(repaint: position);

  final Animation<double> position;
  final RRect tickFundamentalRRect;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = new Paint();

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);

    final int activeTick = (_kTickCount * position.value).floor();

    for (int i = 0; i < _kTickCount; ++i) {
      final double t =
          (((i + activeTick) % _kTickCount) / _kHalfTickCount).clamp(0.0, 1.0);
      paint.color = Color.lerp(_kActiveTickColor, _kTickColor, t);
      canvas.drawRRect(tickFundamentalRRect, paint);
      canvas.rotate(-_kTwoPI / _kTickCount);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HtRefreshIndicatorPainter oldPainter) {
    return oldPainter.position != position;
  }
}
