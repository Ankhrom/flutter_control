import 'package:flutter/cupertino.dart';
import 'package:flutter_control/core.dart';

/// Holder of current root context.
final _context = ActionControl<BuildContext>.broadcast();

const _baseKey = GlobalObjectKey<ControlBaseState>(ControlBase);
const _scopeKey = GlobalObjectKey(ControlScope);

typedef AppBuilder = Widget Function(BuildContext context, Key key, Widget home);

class ControlScope extends InheritedWidget {
  ControlScope({Key key, Widget child}) : super(key: key ?? GlobalObjectKey(child), child: child) {
    Control.factory().swap<ControlScope>(value: this);
  }

  factory ControlScope.empty() => ControlScope(child: EmptyWidget());

  GlobalKey<ControlBaseState> get baseKey => _baseKey;

  GlobalKey get scopeKey => _scopeKey;

  /// Returns current context from [contextHolder]
  BuildContext get rootContext => _context.value;

  /// Sets new root context to [contextHolder]
  set rootContext(BuildContext context) => _context.value = context;

  ActionSubscription<BuildContext> subscribeContextChanges(ValueCallback<BuildContext> callback) => _context.subscribe(callback);

  ActionSubscription<BuildContext> subscribeNextContextChange(ValueCallback<BuildContext> callback) => _context.once(callback);

  bool notifyControlState([dynamic state]) {
    if (baseKey.currentState != null && baseKey.currentState.mounted) {
      baseKey.currentState.notifyState(state);

      return true;
    }

    printDebug('ControlBase is not in Widget Tree! (ControlScope.baseKey)');
    printDebug('Trying to notify ControlScope.scopeKey ..');

    if (scopeKey.currentState != null && scopeKey.currentState.mounted) {
      if (scopeKey.currentState is StateNotifier) {
        (scopeKey.currentState as StateNotifier).notifyState(state);
      } else {
        printDebug('Found State is not StateNotifier, Trying to call setState directly..');
        // ignore: invalid_use_of_protected_member
        scopeKey.currentState.setState(() {});
      }

      return true;
    }

    printDebug('No State to notify found.');

    return false;
  }

  @override
  bool updateShouldNotify(ControlScope oldWidget) {
    return false;
  }
}

class ControlBase extends StatefulWidget {
  final bool debug;
  final String defaultLocale;
  final Map<String, String> locales;
  final bool loadLocalization;
  final Map entries;
  final Map<Type, Initializer> initializers;
  final Injector injector;
  final List<PageRouteProvider> routes;
  final Initializer<ControlTheme> theme;
  final WidgetBuilder loader;
  final ControlWidgetBuilder<ControlArgs> root;
  final AppBuilder app;
  final VoidCallback onInit;

  /// Root [Widget] for whole app.
  ///
  /// [debug] extra debug console prints.
  /// [defaultLocale] key of default locale. First localization will be used if this value is not set.
  /// [locales] map of supported localizations. Key - locale (en, en_US). Value - asset path.
  /// [loadLocalization] loads localization during [ControlBase] initialization.
  /// [entries] map of Controllers/Models to init and fill into [ControlFactory].
  /// [initializers] map of dynamic initializers to store in [ControlFactory].
  /// [theme] custom [ControlTheme] builder.
  /// [loader] widget to show during loading and initializing control, localization.
  /// [root] first Widget after loading finished.
  /// [app] builder of App - [WidgetsApp] is expected - [MaterialApp], [CupertinoApp]. Set [AppBuilder.key] and [AppBuilder.home] from builder to App Widget.
  const ControlBase({
    this.debug: false,
    this.defaultLocale,
    this.locales,
    this.loadLocalization: true,
    this.entries,
    this.initializers,
    this.injector,
    this.routes,
    this.theme,
    this.loader,
    @required this.root,
    @required this.app,
    this.onInit,
  }) : super(key: _baseKey);

  @override
  State<StatefulWidget> createState() => ControlBaseState();
}

/// Creates State for BaseApp.
/// AppControl and MaterialApp is build here.
/// This State is meant to be used as root.
/// BuildContext from local Builder is used as root context.
class ControlBaseState extends State<ControlBase> implements StateNotifier {
  final _args = ControlArgs({LoadingStatus: LoadingStatus.progress});

  bool _loading = true;

  LoadingStatus get loadingStatus => _args[LoadingStatus];

  bool get loading => _loading || loadingStatus != LoadingStatus.done;

  WidgetInitializer _rootBuilder;
  WidgetInitializer _loadingBuilder;

  @override
  void notifyState([state]) {
    setState(() {
      if (state is ControlArgs) {
        _args.combine(state);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    if (widget.loader != null) {
      _loadingBuilder = WidgetInitializer.of(widget.loader);
    } else {
      _args[LoadingStatus] = LoadingStatus.done;
      _loadingBuilder = WidgetInitializer.of((context) {
        printDebug('build default loader');

        return Container(
          color: Theme.of(context).canvasColor,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
        );
      });
    }

    _rootBuilder = WidgetInitializer.control(widget.root);

    BroadcastProvider.subscribe<LocalizationArgs>(BaseLocalization, (args) async {
      if (args.changed && await ControlProvider.get<BaseLocalization>().isSystemLocaleActive(context)) {
        setState(() {
          _loading = false;
        });
      }
    });

    _initControl();
  }

  void _initControl() async {
    if (!Control.isInitialized) {
      Control.init(
        debug: widget.debug,
        defaultLocale: widget.defaultLocale,
        locales: widget.locales ?? {'en': null},
        entries: widget.entries ?? {},
        initializers: widget.initializers ?? {},
        injector: widget.injector,
        routes: widget.routes,
        theme: widget.theme,
      );
    }

    if (widget.loadLocalization && !ControlProvider.get<BaseLocalization>().isActive) {
      _context.once((context) => Control.initLocalization(context: context));
    } else {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ControlScope(
      key: null,
      child: widget.app(
        context,
        _scopeKey,
        Builder(
          builder: (context) => _buildHome(context),
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    _context.value = context;

    return loading
        ? _loadingBuilder.getWidget(
            context,
            args: {
              ControlBaseState: this,
              ControlArgs: _args,
            },
          )
        : _rootBuilder.getWidget(
            context,
            args: {
              ControlBaseState: this,
              ControlArgs: _args,
            },
          );
  }
}

class EmptyWidget extends Widget {
  @override
  Element createElement() => EmptyElement(this);
}

class EmptyElement extends Element {
  EmptyElement(Widget widget) : super(widget);

  @override
  void forgetChild(Element child) {
    printDebug('empty element: forget');
  }

  @override
  void performRebuild() {
    printDebug('empty element: rebuild');
  }
}
