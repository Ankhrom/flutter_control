import 'package:flutter_control/core.dart';

import 'cards_page.dart';

class CardsController extends BaseController with RouteController {
  final cards = ListControl<CardModel>();
  final countLabel = StringControl();

  CardsController() {
    cards.subscribe((value) => countLabel.setValue('${value.length}'));
  }

  @override
  void onInit(Map args) {
    super.onInit(args);

    factory.subscribe<CardModel>('remove_card', (card) => removeCard(card));
  }

  void addCard() => newCard('${localize('card')} ${cards.length}');

  CardModel newCard(String title) {
    if (title == null || title.isEmpty) {
      return null; //TODO: show error
    }

    final card = CardModel(title);

    cards.add(card);

    return card;
  }

  void removeCard(CardModel item) => cards.remove(item);

  openCard(CardModel item) => openPage(DetailPage.route(), args: {'card': item});

  @override
  void dispose() {
    super.dispose();

    cards.clear(disposeItems: true);
    cards.dispose();
  }
}

class DetailController extends BaseController with RouteController {
  CardModel _model;

  ListControl<CardItemModel> get items => _model.items;

  String get title => _model.title;

  @override
  void onInit(Map args) {
    super.onInit(args);

    _model = ArgProvider.map<CardModel>(args);
  }

  void addItem() => newItem('${localize('item')} ${items.length}');

  CardItemModel newItem(String title) {
    if (title == null || title.isEmpty) {
      return null; //TODO: show error
    }

    final item = CardItemModel(_model, title);

    items.add(item);

    return item;
  }

  void deleteSelf() {
    factory.broadcast('remove_card', _model);
    close();
  }
}

class CardModel extends BaseModel {
  final String title;
  final countLabel = StringControl();
  final progress = DoubleControl();
  final items = ListControl<CardItemModel>();

  CardModel(this.title) {
    progress.subscribe((list) => _updateProgress());
  }

  void _updateProgress() {
    final sum = items.length;
    final num = items.where((item) => item.done.isTrue).length;

    if (sum == 0) {
      countLabel.setValue(localize('empty'));
      progress.setValue(0.0);
      return;
    }

    countLabel.setValue('$num/$sum');
    progress.setValue(num / sum);
  }

  @override
  void dispose() {
    super.dispose();

    countLabel.dispose();
    progress.dispose();
    items.clear(disposeItems: true);
    items.dispose();
  }
}

class CardItemModel extends BaseModel {
  final String title;
  final done = BoolControl();

  CardItemModel(CardModel parent, this.title) {
    done.subscribe((value) => parent._updateProgress());
  }

  void changeState(bool value) => done.setValue(value);

  void toggle() => done.toggle();

  @override
  void dispose() {
    super.dispose();

    done.dispose();
  }
}