// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:fancy_syntax/syntax.dart';
import 'package:mdv/mdv.dart' as mdv;

import 'person.dart';

main() {
  mdv.initialize();
  var john = new Person('John', 'Messerly', ['A', 'B', 'C']);
  var justin = new Person('Justin', 'Fagnani', ['D', 'E', 'F']);
  var globals = {
    'uppercase': (String v) => v.toUpperCase(),
    'people': [john, justin],
  };

  TemplateElement.syntax['fancy'] = new FancySyntax(globals: globals);

  query('#test').model = john;
  query('#test2').model = john;
}
