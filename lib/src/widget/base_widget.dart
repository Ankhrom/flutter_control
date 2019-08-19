import 'dart:async';

import 'package:flutter_control/core.dart';

class WidgetControlHolder implements Disposable {
  ControlState state;
  Route route;
  Map<String, dynamic> args;

  bool get initialized => state != null;

  WidgetControlHolder copy() => WidgetControlHolder()
    ..state = state
    ..route = route
    ..args = args;

  @override
  void dispose() {
    state = null;
    args = null;
  }
}

/// [ControlWidget] with just one init Controller.
abstract class SingleControlWidget<T extends BaseController> extends ControlWidget {
  T get controller => controllers[0];

  SingleControlWidget({Key key}) : super(key: key);

  @override
  List<BaseController> initControllers() {
    return [initController()];
  }

  @protected
  T initController() => getControl<T>();
}

/// [ControlWidget] with no init Controllers.
abstract class BaseControlWidget extends ControlWidget {
  BaseControlWidget({Key key}) : super(key: key);

  @override
  List<BaseController> initControllers() => null;
}

/// Base [StatefulWidget] to cooperate with [BaseController].
/// [BaseController]
/// [StateController]
///
/// [RouteControl] & [RouteController]
/// [RouteHandler] & [PageRouteProvider]
///
/// [ControlFactory]
/// [AppControl]
/// [BaseLocalization]
///
/// [ControlState]
/// [_ControlTickerState]
/// [_ControlSingleTickerState]
//TODO: [get] performance
abstract class ControlWidget extends StatefulWidget with LocalizationProvider implements Initializable, Disposable {
  /// Holder for [State] nad Controllers.
  final holder = WidgetControlHolder();

  /// Widget's [State]
  /// [holder] - [onInitState]
  @protected
  ControlState get state => holder?.state;

  /// List of Controllers passed during construction phase.
  /// [holder] - [initControllers]
  List<BaseController> get controllers => holder?.state?.controllers;

  /// Context of Widget's [State]
  BuildContext get context => state?.context;

  /// Instance of [ControlFactory].
  @protected
  ControlFactory get factory => ControlFactory.of(this);

  /// Instance of [AppControl].
  @protected
  AppControl get control => AppControl.of(context);

  /// Instance of [Device].
  /// Helper for [MediaQuery].
  @protected
  Device get device => Device(MediaQuery.of(context));

  /// Instance of nearest [ThemeData].
  @protected
  ThemeData get theme => Theme.of(context);

  /// Instance of nearest [TextTheme].
  @protected
  TextTheme get font => theme.textTheme;

  /// Instance of nearest [TextTheme].
  @protected
  TextTheme get fontPrimary => theme.primaryTextTheme;

  /// Instance of nearest [TextTheme].
  @protected
  TextTheme get fontAccent => theme.accentTextTheme;

  /// Default constructor
  ControlWidget({Key key}) : super(key: key);

  /// Called during construction phase.
  /// Returned controllers will be notified during Widget/State initialization.
  @protected
  List<BaseController> initControllers();

  @override
  ControlState<ControlWidget> createState() => ControlState();

  /// When [RouteHandler] is used, then this function is called right after Widget construction. +
  /// All controllers (from [initControllers]) are initialized too.
  @override
  @protected
  @mustCallSuper
  void init(Map<String, dynamic> args) => holder.args = args;

  /// Called during State initialization.
  /// All controllers (from [initControllers]) are subscribed to this Widget and given State.
  @protected
  @mustCallSuper
  void onInitState(ControlState state) {
    notifyWidget(state);

    controllers?.forEach((controller) {
      controller.init(holder.args);
      controller.subscribe(this);

      if (controller is AnimationInitializer && state is TickerProvider) {
        (controller as AnimationInitializer).onTickerInitialized(state as TickerProvider);
      }

      if (controller is StateController) {
        controller.subscribe(state);
        state._createSub(controller);
        controller.onStateInitialized();
      }
    });
  }

  /// Called by State whenever [holder] isn't initialized or when something has dramatically changed in Widget - State relationship.
  @protected
  void notifyWidget(ControlState state) {
    assert(() {
      if (holder.initialized) {
        printDebug('something is maybe wrong, state reinitialized...');
        printDebug('old state: ${this.state}');
        printDebug('new state: $state');
      }
      return true;
    }());

    if (this.state == state) {
      return;
    }

    holder.state = state;
  }

  /// Notifies [State] of this [Widget].
  void notifyState() => holder.state?.notifyState();

  /// Looks for [Type] in initialized controllers, then look up whole factory.
  @protected
  T getControl<T>() => factory.find<T>(controllers);

  /// Returns context of this widget or [root] context that is stored in [AppControl]
  BuildContext getContext({bool root: false}) => root ? control.rootContext ?? context : context;

  /// [StatelessWidget.build]
  /// [StatefulWidget.build]
  @protected
  Widget build(BuildContext context);

  /// Disposes and removes all [controllers].
  /// Controller can prevent disposing [BaseController.preventDispose].
  @override
  @mustCallSuper
  void dispose() {
    printDebug('dispose ${this.toString()}');
  }
}

/// Base State for ControlWidget and StateController
/// State is subscribed to Controller which notifies back about state changes.
class ControlState<U extends ControlWidget> extends State<U> implements StateNotifier {
  /// List of Subscriptions from [StateController]s
  List<ControlSubscription> _stateSubs;

  List<BaseController> controllers;

  @override
  void initState() {
    super.initState();

    controllers = widget.initControllers();
    widget.onInitState(this);
  }

  @override
  void notifyState([state]) {
    setState(() {});
  }

  @protected
  void notifyWidget() {
    if (!widget.holder.initialized) {
      widget.notifyWidget(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    notifyWidget(); //TODO: I don't like it here :(

    return widget.build(context);
  }

  void _createSub(StateController controller) {
    if (_stateSubs == null) {
      _stateSubs = List<ControlSubscription>();
    }

    _stateSubs.add(controller.subscribeStateNotifier(notifyState));
  }

  /// Disposes and removes all [controllers].
  /// Controller can prevent disposing [BaseController.preventDispose].
  /// Then disposes Widget.
  @override
  @mustCallSuper
  void dispose() {
    super.dispose();

    if (_stateSubs != null) {
      _stateSubs.forEach((sub) => sub.cancel());
      _stateSubs.clear();
      _stateSubs = null;
    }

    controllers?.forEach((controller) {
      if (!controller.preventDispose) {
        controller.dispose();
      }
    });

    widget.holder.dispose();
    widget.dispose();
  }
}

/// [ControlState] with [TickerProviderStateMixin]
class _ControlTickerState<U extends ControlWidget> extends ControlState<U> with TickerProviderStateMixin {}

/// [ControlState] with [SingleTickerProviderStateMixin]
class _ControlSingleTickerState<U extends ControlWidget> extends ControlState<U> with SingleTickerProviderStateMixin {}

/// Helps [ControlWidget] to create State with [TickerProviderStateMixin]
/// Override [singleTicker] to create State with [SingleTickerProviderStateMixin].
mixin TickerControl on ControlWidget {
  @protected
  bool get singleTicker => false;

  @protected
  TickerProvider get ticker => holder.state as TickerProvider;

  @override
  ControlState<ControlWidget> createState() => singleTicker ? _ControlSingleTickerState() : _ControlTickerState();
}

/// Mixin class to enable navigation for [ControlWidget]
mixin RouteControl on ControlWidget implements RouteNavigator {
  NavigatorState get navigator => Navigator.of(context);

  NavigatorState get rootNavigator => Navigator.of(getContext(root: true));

  @override
  void init(Map<String, dynamic> args) {
    super.init(args);

    holder.route = ArgProvider.map<Route>(args, key: ControlKey.initData);

    if (holder.route != null) {
      printDebug('${this.toString()} at route: ${holder.route.settings.name}');
    }
  }

  @override
  Future<dynamic> openRoute(Route route, {bool root: false, bool replacement: false}) {
    if (replacement) {
      return navigator.pushReplacement(route);
    } else {
      return (root ? rootNavigator : navigator).push(route);
    }
  }

  @override
  Future<dynamic> openRoot(Route route) {
    return navigator.pushAndRemoveUntil(route, (pop) => false);
  }

  @override
  Future<dynamic> openDialog(WidgetBuilder builder, {bool root: false, DialogType type: DialogType.popup}) async {
    final dialogContext = getContext(root: root);

    //TODO: dialogs
    switch (type) {
      case DialogType.popup:
        return await showDialog(context: dialogContext, builder: (context) => builder(context));
      case DialogType.sheet:
        return await showModalBottomSheet(context: dialogContext, builder: (context) => builder(context));
      case DialogType.dialog:
        return await Navigator.of(dialogContext).push(MaterialPageRoute(builder: (BuildContext context) => builder(context), fullscreenDialog: true));
      case DialogType.dock:
        return showBottomSheet(context: dialogContext, builder: (context) => builder(context));
    }

    return null;
  }

  void backTo({Route route, String identifier, bool Function(Route<dynamic>) predicate}) {
    if (route != null) {
      navigator.popUntil((item) => item == route);
    }

    if (identifier != null) {
      navigator.popUntil((item) => item.settings.name == identifier);
    }

    if (predicate != null) {
      navigator.popUntil(predicate);
    }
  }

  @override
  void backToRoot() {
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  void close([dynamic result]) {
    if (holder.route != null) {
      closeRoute(holder.route, result);
    } else {
      navigator.pop(result);
    }
  }

  @override
  void closeRoute(Route route, [dynamic result]) {
    if (route.isCurrent) {
      navigator.pop(result);
    } else {
      // ignore: invalid_use_of_protected_member
      route.didComplete(result);
      navigator.removeRoute(route);
    }
  }
}
