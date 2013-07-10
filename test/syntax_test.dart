// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:fancy_syntax/syntax.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';
import 'package:observe/observe.dart';
import 'package:mdv/mdv.dart' as mdv;

main() {
  mdv.initialize();
  useHtmlEnhancedConfiguration();

  group('syntax', () {

    setUp(() {
      TemplateElement.syntax['fancy'] = new FancySyntax();
    });

    test('should make two-way bindings to inputs', () {
      var person = new Person('John', 'Messerly', ['A', 'B', 'C']);
      query('#test').model = person;
      return new Future.delayed(new Duration()).then((_) {
        InputElement input = query('#input');
        expect(input.value, 'John');
        input.focus();
        input.value = 'Justin';
        input.blur();
        var event = new Event('change');
        // TODO(justin): figure out how to trigger keyboard events to test
        // two-way bindings
      });
    });

  });
}

class Person extends Object with ObservableMixin {
  static const _FIRST_NAME = const Symbol('firstName');
  static const _LAST_NAME = const Symbol('lastName');
  static const _ITEMS = const Symbol('items');
  static const _GET_FULL_NAME = const Symbol('getFullName');

  String _firstName;
  String _lastName;
  List<String> _items;

  Person(this._firstName, this._lastName, this._items);

  String get firstName => _firstName;

  void set firstName(String value) {
    _firstName = value;
    notifyChange(new PropertyChangeRecord(_FIRST_NAME));
  }

  String get lastName => _lastName;

  void set lastName(String value) {
    _lastName = value;
    notifyChange(new PropertyChangeRecord(_LAST_NAME));
  }

  String getFullName() => '$_firstName $_lastName';

  List<String> get items => _items;

  void set items(List<String> value) {
    _items = value;
    notifyChange(new PropertyChangeRecord(_ITEMS));
  }

  String toString() => "Person(firstName: $_firstName, lastName: $_lastName)";

  getValueWorkaround(key) {
    if (key == _FIRST_NAME) return _firstName;
    if (key == _LAST_NAME) return _lastName;
    if (key == _GET_FULL_NAME) return getFullName();
    if (key == _ITEMS) return _items;
  }

  void setValueWorkaround(key, Object value) {
    if (key == _FIRST_NAME) {
      firstName = value;
    } else if (key == _LAST_NAME) {
      lastName = value;
    } else if (key == _ITEMS) {
      items = value;
    }
  }

}
