// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library eval_test;

import 'package:fancy_syntax/eval.dart';
import 'package:fancy_syntax/filter.dart';
import 'package:fancy_syntax/parser.dart';
import 'package:unittest/unittest.dart';

Object evalString(String s, [Object target, Map scope]) =>
    eval(new Parser(s).parse(), target: target, scope: scope);

expectEval(String s, dynamic matcher, [Object target, Map scope]) =>
    expect(eval(new Parser(s).parse(), target: target, scope: scope),
        matcher, reason: s);

main() {
  group('eval', () {
    test('should return the target for an empty expression', () {
      expectEval('', 'target', 'target');
    });

    test('should return a literal int', () {
      expectEval('1', 1);
      expectEval('+1', 1);
      expectEval('-1', -1);
    });

    test('should return a literal double', () {
      expectEval('1.2', 1.2);
      expectEval('+1.2', 1.2);
      expectEval('-1.2', -1.2);
    });

    test('should return a literal string', () {
      expectEval('"hello"', "hello");
      expectEval("'hello'", "hello");
    });

    test('should return a literal boolean', () {
      expectEval('true', true);
      expectEval('false', false);
    });

    test('should evaluate unary operators', () {
      expectEval('+a', 2, null, {'a': 2});
      expectEval('-a', -2, null, {'a': 2});
      expectEval('!a', false, null, {'a': true});
    });

    test('should evaluate binary operators', () {
      expectEval('1 + 2', 3);
      expectEval('2 - 1', 1);
      expectEval('4 / 2', 2);
      expectEval('2 * 3', 6);

      expectEval('1 == 1', true);
      expectEval('1 == 2', false);
      expectEval('1 != 1', false);
      expectEval('1 != 2', true);

      expectEval('1 > 1', false);
      expectEval('1 > 2', false);
      expectEval('2 > 1', true);
      expectEval('1 >= 1', true);
      expectEval('1 >= 2', false);
      expectEval('2 >= 1', true);
      expectEval('1 < 1', false);
      expectEval('1 < 2', true);
      expectEval('2 < 1', false);
      expectEval('1 <= 1', true);
      expectEval('1 <= 2', true);
      expectEval('2 <= 1', false);

      expectEval('true || true', true);
      expectEval('true || false', true);
      expectEval('false || true', true);
      expectEval('false || false', false);

      expectEval('true && true', true);
      expectEval('true && false', false);
      expectEval('false && true', false);
      expectEval('false && false', false);
    });

    test('should invoke a method on the target', () {
      var foo = new Foo('foo', 2, 3);
      expectEval('x()', foo.x(), foo);
      expectEval('a', foo.a, foo);
    });

    test('should invoke chained methods', () {
      var foo = new Foo('foo', 2, 3);
      expectEval('a.length', foo.a.length, foo);
      expectEval('x().toString()', foo.x().toString(), foo);
      expectEval('a.substring(2)', foo.a.substring(2), foo);
      expectEval('a()()', 1, null, {'a': () => () => 1});
    });

    test('should invoke a top-level function', () {
      expectEval('x()', 42, null, {'x': () => 42});
      expectEval('x(5)', 5, null, {'x': (i) => i});
      expectEval('y(5, 10)', 50, null, {'y': (i, j) => i * j});
    });

    test('should give precedence to top-level functions over methods', () {
      var foo = new Foo('foo', 2, 3);
      expectEval('x()', 42, foo, {'x': () => 42});
    });

    test('should invoke the [] operator', () {
      var map = {'a': 1, 'b': 2};
      expectEval('map["a"]', 1, null, {'map': map});
      expectEval('map["a"] + map["b"]', 3, null, {'map': map});
    });

    test('should call a filter', () {
      var topLevel = {
        'a': 'foo',
        'uppercase': (s) => s.toUpperCase(),
      };
      expectEval('a | uppercase', 'FOO', null, topLevel);
    });

    test('should call a transformer', () {
      var topLevel = {
        'a': '42',
        'parseInt': parseInt,
        'add': add,
      };
      expectEval('a | parseInt()', 42, null, topLevel);
      expectEval('a | parseInt(8)', 34, null, topLevel);
      expectEval('a | parseInt() | add(10)', 52, null, topLevel);
    });
  });
}

class Foo {
  String a;
  int b;
  int c;

  Foo(this.a, this.b, this.c);

  int x() => b * c;
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
