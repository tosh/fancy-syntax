// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library eval_test;

import 'package:fancy_syntax/eval.dart';
import 'package:fancy_syntax/parser.dart';
import 'package:unittest/unittest.dart';

class Foo {
  String a;
  int b;
  int c;

  Foo(this.a, this.b, this.c);

  int x() => b * c;
}

Object evalString(String s, [Object target, Map topLevel]) =>
    eval(new Parser(s).parse(), target: target, topLevel: topLevel);

expectEval(String s, dynamic matcher, [Object target, Map topLevel]) =>
    expect(eval(new Parser(s).parse(), target: target, topLevel: topLevel),
        matcher, reason: s);

main() {
  group('eval', () {
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

  });
}
