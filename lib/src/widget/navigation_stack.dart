import 'dart:async';

import 'package:flutter_control/core.dart';

/// Helper interface to notify [State]
abstract class _StackNavigator {
  /// Navigate back withing [NavigatorStack]
  /// Returns [true] if navigation is handled by Controller.
  bool navigateBack();

  /// Navigate to first Widget of [NavigatorStack]
  void navigateToRoot();
}

/// Controller for [NavigatorStack]
///
/// [NavigatorStackController]
/// [WillPopScope]
/// [RouteHandler]  [RouteController]
class NavigatorController extends BaseController implements _StackNavigator {
  /// Data for menu item.
  /// Mostly used in combination with [NavigatorStackController]
  MenuItem menu;

  /// Implementation of StackNavigator.
  _StackNavigator _navigator;

  /// Check if navigator is set during subscribe (State init) phase.
  bool get isNavigatorAvailable => _navigator != null;

  /// Data for menu item.
  bool _isSelected = false;

  /// Data for menu item.
  /// Returns if this controller is selected.
  /// Mostly used in combination with [NavigatorStackController]
  bool get isSelected => _isSelected;

  /// Data for menu item.
  /// Sets selection for this controller.
  /// Mostly used in combination with [NavigatorStackController]
  set isSelected(value) {
    _isSelected = value;
    if (onSelectionChanged != null) {
      onSelectionChanged(value);
    }
  }

  /// Notifies about selection changes.
  Action<bool> onSelectionChanged;

  /// Default constructor
  NavigatorController({this.menu});

  @override
  void subscribe(object) {
    super.subscribe(object);

    if (object is _StackNavigator) {
      _navigator = object;
    }
  }

  @override
  bool navigateBack() => _navigator?.navigateBack();

  @override
  void navigateToRoot() => _navigator?.navigateToRoot();

  /// Helper function for [WillPopScope].
  /// Returns negation of [navigateBack] as Future.
  Future<bool> popScope() async => !navigateBack();
}

/// Creates new [Navigator] and all underling Widgets will be pushed to this stack.
/// With [overrideNavigation] Widget will create [WillPopScope] and handles back button.
///
/// [NavigatorStack.single] - Single navigator. Typically used inside other page to show content progress.
/// [NavigatorStack.pages] - Multiple [NavigatorStack]s in [Stack]. Only selected Controllers are visible - [Offstage].
/// Typically just one page is visible - usable with [BottomNavigationBar] to preserve navigation of separated pages.
/// [NavigatorStack.menu] - Simplified version of [NavigatorStack.pages], can be used if access to [NavigatorController]s is not required.
///
/// [NavigatorStackController] is used to navigate between multiple [NavigatorStack]s.
///
/// [RouteHandler] [RouteController]
class NavigatorStack extends ControlWidget implements _StackNavigator {
  final ContextHolder _ctx = ContextHolder();

  final NavigatorController controller;
  final WidgetBuilder builder;
  final bool overrideNavigation;

  BuildContext get navContext => _ctx.context;

  /// Default constructor
  NavigatorStack._(
      {@required this.controller,
      @required this.builder,
      this.overrideNavigation: false})
      : super(key: ObjectKey(controller));

  /// Creates new [Navigator] and all underling Widgets will be pushed to this stack.
  /// With [overrideNavigation] Widget will create [WillPopScope] and handles back button.
  ///
  /// Single navigator. Typically used inside other page to show content progress.
  ///
  /// [NavigatorStack]
  static NavigatorStack single(
      {NavigatorStack controller,
      @required WidgetBuilder builder,
      bool overrideNavigation: false}) {
    return NavigatorStack._(
      controller: controller ?? NavigatorController(),
      builder: builder,
      overrideNavigation: overrideNavigation,
    );
  }

  /// Creates new [Navigator] and all underling Widgets will be pushed to this stack.
  /// With [overrideNavigation] Widget will create [WillPopScope] and handles back button.
  ///
  /// [NavigatorStack.pages] - Multiple [NavigatorStack]s in [Stack]. Only selected Controllers are visible - [Offstage].
  /// Typically just one page is visible - usable with [BottomNavigationBar] to preserve navigation of separated pages.
  /// [NavigatorStack.menu] - Simplified version of [NavigatorStack.pages], can be used if access to [NavigatorController]s is not required.
  ///
  /// [NavigatorStackController] is used to navigate between multiple [NavigatorStack]s.
  ///
  /// [NavigatorStack]
  static _NavigatorStackOffstage pages(
      {Key key,
      NavigatorStackController controller,
      @required List<NavigatorStack> pages,
      bool overrideNavigation: true}) {
    return _NavigatorStackOffstage(
      pages: pages,
      controller: controller ?? NavigatorStackController,
      overrideNavigation: overrideNavigation,
    );
  }

  /// Creates new [Navigator] and all underling Widgets will be pushed to this stack.
  /// With [overrideNavigation] Widget will create [WillPopScope] and handles back button.
  ///
  /// [NavigatorStack.pages] - Multiple [NavigatorStack]s in [Stack]. Only selected Controllers are visible - [Offstage].
  /// Typically just one page is visible - usable with [BottomNavigationBar] to preserve navigation of separated pages.
  /// [NavigatorStack.menu] - Simplified version of [NavigatorStack.pages], can be used if access to [NavigatorController]s is not required.
  ///
  /// [NavigatorStackController] is used to navigate between multiple [NavigatorStack]s.
  ///
  /// [NavigatorStack]
  static _NavigatorStackOffstage menu(
      {NavigatorStackController controller,
      @required Map<MenuItem, WidgetBuilder> pages,
      bool overrideNavigation: true}) {
    final items = List<NavigatorStack>();

    pages.forEach((key, value) => items.add(NavigatorStack._(
          controller: NavigatorController(menu: key),
          builder: value,
          overrideNavigation: false,
        )));

    return NavigatorStack.pages(
      controller: controller,
      pages: items,
      overrideNavigation: overrideNavigation,
    );
  }

  @override
  List<BaseController> initControllers() {
    return [controller];
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator(
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) {
          _ctx.changeContext(context);
          return builder(context);
        });
      },
    );

    if (overrideNavigation) {
      return WillPopScope(
        onWillPop: controller.popScope,
        child: navigator,
      );
    }

    return navigator;
  }

  @override
  bool navigateBack() {
    if (Navigator.of(navContext).canPop()) {
      Navigator.of(navContext).pop();

      return true;
    }

    return false;
  }

  @override
  void navigateToRoot() {
    Navigator.of(navContext).popUntil((route) => route.isFirst);
  }
}

//########################################################################################
//########################################################################################
//########################################################################################

/// Controller for:
/// [NavigatorStack.pages] - Multiple [NavigatorStack]s in [Stack]. Only selected Controllers are visible - [Offstage].
/// Typically just one page is visible - usable with [BottomNavigationBar] to preserve navigation of separated pages.
/// [NavigatorStack.menu] - Simplified version of [NavigatorStack.pages], can be used if access to [NavigatorController]s is not required.
///
/// [NavigatorStack]
class NavigatorStackController extends StateController {
  /// List of Controllers set in Widget construct phase.
  List<NavigatorController> _items;

  /// List of Controllers set in Widget construct phase.
  List<NavigatorController> get items => _items;

  /// List of MenuItems set in Widget construct phase.
  List<MenuItem> get menuItems =>
      _items.map((item) => item.menu).toList(growable: false);

  /// Current page index.
  int _pageIndex = 0;

  /// Returns current page index.
  /// Use [setPageIndex] to change active controller.
  /// Use [onPageChanged] to be notified about changes.
  int get currentPageIndex => _pageIndex;

  /// Returns current controller - based on [currentPageIndex].
  NavigatorController get currentController => _items[currentPageIndex];

  /// Notifies about page changes.
  /// Can be used with [ControlBuilder] to rebuild menu or highlight active widget.
  final onPageChanged = ActionControl<int>.broadcast(0);

  /// Sets page index and notifies [onPageChanged]
  /// Given index is clamped between valid indexes [items.length]
  /// Notifies [State] to switch [Offstage] of old/new active controller.
  void setPageIndex(int index) {
    currentController.isSelected = false;

    _pageIndex = index.clamp(0, _items.length - 1);

    currentController.isSelected = true;

    if (onPageChanged != null) {
      onPageChanged.setValue(currentPageIndex);
    }

    notifyState();
  }

  /// Navigates back withing active [NavigatorStack] or sets page index to 0.
  /// Returns [true] if navigation is handled by Controller.
  bool navigateBack() {
    if (currentPageIndex > 0) {
      if (!currentController.navigateBack()) {
        setPageIndex(0);
      }

      return true;
    }

    return currentController.navigateBack();
  }

  /// Helper function for [WillPopScope].
  /// Returns negation of [navigateBack] as Future.
  Future<bool> popScope() async => !navigateBack();
}

//TODO: custom animation in/out
/// [NavigatorStack]
/// [NavigatorController]
/// [NavigatorStackController]
class _NavigatorStackOffstage extends ControlWidget {
  final NavigatorStackController controller;
  final List<NavigatorStack> pages;
  final bool overrideNavigation;

  _NavigatorStackOffstage({
    @required this.controller,
    @required this.pages,
    this.overrideNavigation: true,
  }) : super(key: ObjectKey(controller)) {
    assert(pages.length > 0);
  }

  @override
  List<BaseController> initControllers() {
    controller._items =
        pages.map((page) => page.controller).toList(growable: false);
    controller.currentController.isSelected = true;

    return [controller];
  }

  @override
  Widget build(BuildContext context) {
    final list = List<Offstage>();

    pages.forEach((page) {
      list.add(Offstage(
        key: ObjectKey(page.controller),
        offstage: !page.controller.isSelected,
        child: page,
      ));
    });

    if (overrideNavigation) {
      return WillPopScope(
        onWillPop: controller.popScope,
        child: Stack(
          children: list,
        ),
      );
    }

    return Stack(
      children: list,
    );
  }
}