// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library assign_test;

import 'package:fancy_syntax/assign.dart';
import 'package:fancy_syntax/filter.dart';
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

    test('should assign through transformers', () {
      var foo = new Foo(name: '42', age: 32);
      var scope = {
        'a': '42',
        'parseInt': parseInt,
        'add': add,
      };
      assign(parse('age | add(7)'), foo, 29, scope: scope);
      expect(foo.age, 22);
      assign(parse('name | parseInt() | add(10)'), foo, 29, scope: scope);
      expect(foo.name, '19');
    });

  });
}

class Foo {
  String name;
  int age;
  Foo child;
  List<int> items;

  Foo({this.name, this.age, this.child, this.items});
}

parseInt([int radix = 10]) => new IntToString(radix: radix);

class IntToString extends Transformer<int, String> {
  final int radix;
  IntToString({this.radix: 10});
  int forward(String s) => int.parse(s, radix: radix);
  String reverse(int i) => '$i';
}

add(int i) => new Add(i);

class Add extends Transformer<int, int> {
  final int i;
  Add(this.i);
  int forward(int x) => x + i;
  int reverse(int x) => x - i;
}
