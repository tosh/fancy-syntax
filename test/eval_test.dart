// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library eval_test;

import 'package:fancy_syntax/eval.dart';
import 'package:fancy_syntax/filter.dart';
import 'package:fancy_syntax/parser.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';

Object evalString(String s, [Object model, Map vars]) =>
    eval(new Parser(s).parse(), new Scope(model: model, variables: vars));

expectEval(String s, dynamic matcher, [Object model, Map vars = const {}]) =>
    expect(eval(new Parser(s).parse(), new Scope(model: model, variables: vars)),
        matcher, reason: s);

main() {
  useHtmlEnhancedConfiguration();

  group('eval', () {
    test('should return the model for an empty expression', () {
      expectEval('', 'model', 'model');
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

    test('should invoke a method on the model', () {
      var foo = new Foo(name: 'foo', age: 2);
      expectEval('x()', foo.x(), foo);
      expectEval('name', foo.name, foo);
    });

    test('should invoke chained methods', () {
      var foo = new Foo(name: 'foo', age: 2);
      expectEval('name.length', foo.name.length, foo);
      expectEval('x().toString()', foo.x().toString(), foo);
      expectEval('name.substring(2)', foo.name.substring(2), foo);
      expectEval('a()()', 1, null, {'a': () => () => 1});
    });

    test('should invoke a top-level function', () {
      expectEval('x()', 42, null, {'x': () => 42});
      expectEval('x(5)', 5, null, {'x': (i) => i});
      expectEval('y(5, 10)', 50, null, {'y': (i, j) => i * j});
    });

    test('should give precedence to top-level functions over methods', () {
      var foo = new Foo(name: 'foo', age: 2);
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

    test('should return null if the receiver of a method is null', () {
      expectEval('a.b', null, null, {'a': null});
      expectEval('a.b()', null, null, {'a': null});
    });

    test('should return null if null is invoked', () {
      expectEval('a()', null, null, {'a': null});
    });

    test('should return null if an operand is null', () {
      expectEval('a + b', null, null, {'a': null, 'b': null});
      expectEval('+a', null, null, {'a': null});
    });

    test('should treat null as false', () {
      expectEval('!a', true, null, {'a': null});

      expectEval('a && b', false, null, {'a': null, 'b': true});
      expectEval('a && b', false, null, {'a': true, 'b': null});
      expectEval('a && b', false, null, {'a': null, 'b': false});
      expectEval('a && b', false, null, {'a': false, 'b': null});
      expectEval('a && b', false, null, {'a': null, 'b': null});

      expectEval('a || b', true, null, {'a': null, 'b': true});
      expectEval('a || b', true, null, {'a': true, 'b': null});
      expectEval('a || b', false, null, {'a': null, 'b': false});
      expectEval('a || b', false, null, {'a': false, 'b': null});
      expectEval('a || b', false, null, {'a': null, 'b': null});
    });

  });

  group('assign', () {

    test('should assign a single identifier', () {
      var foo = new Foo(name: 'a');
      assign(parse('name'), 'b', new Scope(model: foo));
      expect(foo.name, 'b');
    });

    test('should assign a sub-property', () {
      var child = new Foo(name: 'child');
      var parent = new Foo(child: child);
      assign(parse('child.name'), 'Joe', new Scope(model: parent));
      expect(parent.child.name, 'Joe');
    });

    test('should assign an index', () {
      var foo = new Foo(items: [1, 2, 3]);
      assign(parse('items[0]'), 4, new Scope(model: foo));
      expect(foo.items[0], 4);
    });

    test('should assign through transformers', () {
      var foo = new Foo(name: '42', age: 32);
      var globals = {
        'a': '42',
        'parseInt': parseInt,
        'add': add,
      };
      var scope = new Scope(model: foo, variables: globals);
      assign(parse('age | add(7)'), 29, scope);
      expect(foo.age, 22);
      assign(parse('name | parseInt() | add(10)'), 29, scope);
      expect(foo.name, '19');
    });

  });

  group('scope', () {
    test('should return fields on the model', () {
      var foo = new Foo(name: 'a', age: 1);
      var scope = new Scope(model: foo);
      expect(scope['name'], 'a');
      expect(scope['age'], 1);
    });

    test('should throw for undefined names', () {
      var scope = new Scope();
      expect(() => scope['a'], throwsException);
    });

    test('should return variables', () {
      var scope = new Scope(variables: {'a': 'A'});
      expect(scope['a'], 'A');
    });

    test("should a field from the parent's model", () {
      var parent = new Scope(variables: {'a': 'A', 'b': 'B'});
      var child = new Scope(variables: {'a': 'a'}, parent: parent);
      expect(child['a'], 'a');
      expect(parent['a'], 'A');
      expect(child['b'], 'B');
    });

  });
}

class Foo {
  String name;
  int age;
  Foo child;
  List<int> items;

  Foo({this.name, this.age, this.child, this.items});

  int x() => age * age;
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
