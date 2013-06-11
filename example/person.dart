// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library person;

import 'package:mdv_observe/mdv_observe.dart';

class Person extends Object with ObservableMixin {
  static const _FIRST_NAME = const Symbol('firstName');
  static const _LAST_NAME = const Symbol('lastName');
  static const _GET_FULL_NAME = const Symbol('getFullName');

  String _firstName;
  String _lastName;

  Person(this._firstName, this._lastName);

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

  String toString() => "Person(firstName: $_firstName, lastName: $_lastName)";

  getValueWorkaround(key) {
    if (key == _FIRST_NAME) return _firstName;
    if (key == _LAST_NAME) return _lastName;
    if (key == _GET_FULL_NAME) return getFullName();
  }

  void setValueWorkaround(key, Object value) {
    if (key == _FIRST_NAME) {
      _firstName = value;
      notifyChange(new PropertyChangeRecord(_FIRST_NAME));
    } else if (key == _LAST_NAME) {
      _lastName = value;
      notifyChange(new PropertyChangeRecord(_LAST_NAME));
    }
  }

}
