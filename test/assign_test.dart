// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library assign_test;

import 'package:fancy_syntax/assign.dart';
import 'package:fancy_syntax/parser.dart';
import 'package:unittest/unittest.dart';

main() {
  group('assign', () {

    test('should assign a single identifier', () {
      var foo = new Foo(name: 'a');
      assign(parse('name'), foo, 'b');
      expect(foo.name, 'b');
    });

    test('should assign a sub-property', () {
      var child = new Foo(name: 'child');
      var parent = new Foo(child: child);
      assign(parse('child.name'), parent, 'Joe');
      expect(parent.child.name, 'Joe');
    });

    test('should assign an index', () {
      var foo = new Foo(items: [1, 2, 3]);
      assign(parse('items[0]'), foo, 4);
      expect(foo.items[0], 4);
    });

  });
}

class Foo {
  String name;
  Foo child;
  List<int> items;

  Foo({this.name, this.child, this.items});
}
