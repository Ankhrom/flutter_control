import 'package:flutter_control/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Control Holder', () {
    test('args', () {
      final holder = WidgetControlHolder();

      holder.addArg({String: 'arg1', 'key': 'arg2'});
      holder.addArg({String: 'arg3'});
      holder.addArg(10);
      holder.addArg([1.0, true]);

      expect(holder.args.length, 5);
      expect(Parse.getArg<String>(holder.args), isNot('arg1'));
      expect(Parse.getArg(holder.args, key: String), 'arg3');
      expect(Parse.getArg<int>(holder.args), 10);
      expect(Parse.getArg<double>(holder.args), 1.0);
    });
  });

  group('Widget', () {
    test('args', () {
      final widget1 = TestWidget('empty');
      final widget2 = TestWidget({'key': 'value'});

      // ignore: invalid_use_of_protected_member
      widget1.init({'init': true});

      widget1.addArg(0);
      widget2.addArg({int: 0});

      expect(widget1.getArg<String>(), 'empty');
      expect(widget1.getArg(key: 'init'), isTrue);
      expect(widget1.getArg<int>(), 0);
      expect(widget1.getArg<double>(defaultValue: 1.0), 1.0);

      expect(widget2.getArg<String>(), 'value');
      expect(widget2.getArg<int>(), 0);
      expect(widget2.getArg<double>(defaultValue: 1.0), 1.0);
    });

    testWidgets('init', (tester) async {
      final widget = TestWidget('empty');

      // ignore: invalid_use_of_protected_member
      widget.init({'init': true});

      await tester.pumpWidget(widget);

      final controller = widget.getControl<TestController>();
      final stringControl = widget.getControl<String>();

      expect(widget.isInitialized, isTrue);
      expect(widget.getArg<String>(), 'empty');
      expect(widget.getArg(key: 'init'), isTrue);

      expect(controller, isNotNull);
      expect(widget.controllers.length, 1);
      expect(controller.isInitialized, isTrue);
      expect(controller.value, isTrue);

      expect(stringControl, isNull);
    });

    testWidgets('single init', (tester) async {
      final widget = TestSingleWidget(TestController());

      // ignore: invalid_use_of_protected_member
      widget.init({'init': true});

      await tester.pumpWidget(widget);

      final controller = widget.controller;

      expect(widget.isInitialized, isTrue);
      expect(widget.getArg(key: 'init'), isTrue);

      expect(controller, isNotNull);
      expect(controller.isInitialized, isTrue);
      expect(controller.value, isTrue);
    });

    testWidgets('arg control init', (tester) async {
      final widget = TestBaseWidget(TestController());

      // ignore: invalid_use_of_protected_member
      widget.init({'init': true});

      await tester.pumpWidget(widget);

      final controller = widget.controllers[0] as TestController;

      expect(widget.isInitialized, isTrue);
      expect(widget.getArg(key: 'init'), isTrue);

      expect(controller, isNotNull);
      expect(controller.isInitialized, isTrue);
      expect(controller.value, isTrue);
    });
  });
}

class TestWidget extends ControlWidget {
  TestWidget(dynamic args) : super(args: args);

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  List<BaseControlModel> initControllers() {
    return [TestController()];
  }
}

class TestBaseWidget extends BaseControlWidget {
  TestBaseWidget(dynamic args) : super(args: args);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class TestSingleWidget extends SingleControlWidget<TestController> {
  TestSingleWidget(TestController controller) : super(args: controller);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class TestController extends BaseController {
  bool value;

  @override
  void onInit(Map args) {
    super.onInit(args);

    value = args.getArg(key: 'init');
  }
}