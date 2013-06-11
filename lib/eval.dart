// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax.eval;

import 'dart:collection';
import 'dart:mirrors';

import 'visitor.dart';
import 'parser.dart';
import 'expression.dart';

final _BINARY_OPERATORS = {
  '+':  (a, b) => a + b,
  '-':  (a, b) => a - b,
  '*':  (a, b) => a * b,
  '/':  (a, b) => a / b,
  '==': (a, b) => a == b,
  '!=': (a, b) => a != b,
  '>':  (a, b) => a > b,
  '>=': (a, b) => a >= b,
  '<':  (a, b) => a < b,
  '<=': (a, b) => a <= b,
  '||': (a, b) => a || b,
  '&&': (a, b) => a && b,
};

final _UNARY_OPERATORS = {
  '+': (a) => a,
  '-': (a) => -a,
  '!': (a) => !a,
};

Object eval(Expression expr, {Object target, Map<String, Object> scope}) {
  var visitor = new MirrorEvaluator(target, scope: scope);
  return visitor.visitExpression(expr);
}

class MirrorEvaluator extends Visitor {
  final Object target;
  final InstanceMirror targetMirror;
  final Map<String, Object> scope;

  MirrorEvaluator(target, {this.scope})
      : target = target, targetMirror = reflect(target);

  visitExpression(Expression e) => e.accept(this);

  visitEmptyExpression(EmptyExpression e) => target;

  visitParenthesizedExpression(ParenthesizedExpression e) =>
    e.expr.accept(this);

  visitInvoke(Invoke i) {
    var args = (i.arguments == null)
        ? []
        : i.arguments.map((a) => a.accept(this)).toList(growable: false);
    if (i.method == null) {
      var receiver = i.receiver.accept(this);
      if (i.isGetter) {
        return receiver;
      } else {
        assert(receiver is Function);
        return _wrap(receiver)(args);
      }
    } else {
      var receiver = i.receiver.accept(this);
      // special case [] because we don't need mirrors
      if (i.method == '[]') {
        assert(args.length == 1);
        return receiver[args[0]];
      } else {
        var mirror = reflect(receiver);
        return (i.isGetter)
            ? _wrap(mirror.getField(new Symbol(i.method)).reflectee)
            : _wrap(mirror.invoke(new Symbol(i.method), args, null).reflectee);
      }
    }
  }

  // This will only be called at the top level of an expression, all other
  // identifiers will be stored as the method of an Invoke node.
  visitIdentifier(Identifier e) {
    String name = e.value;
    if (scope != null && scope.containsKey(name)) {
      return _wrap(scope[name]);
    } else if (target != null) {
      var symbol = new Symbol(name);
      var classMirror = targetMirror.type;
      if (classMirror.variables.containsKey(symbol) ||
          classMirror.getters.containsKey(symbol)) {
        return _wrap(targetMirror.getField(new Symbol(name)).reflectee);
      } else if (classMirror.methods.containsKey(symbol)) {
        return new _InvokeWrapper(targetMirror, symbol);
      }
    }
    throw new EvalException("variable not found: $name");
  }

  visitLiteral(Literal l) => l.value;

  visitBinaryOperator(BinaryOperator o) {
    var left = o.left.accept(this);
    var right = o.right.accept(this);
    var f = _BINARY_OPERATORS[o.operator];
    // TODO(justin): type coercion
    return f(left, right);
  }

  visitUnaryOperator(UnaryOperator o) {
    var e = o.expr.accept(this);
    var f = _UNARY_OPERATORS[o.operator];
    // TODO(justin): type coercion
    return f(e);
  }
}

/**
 * If [v] is a closure, wraps it in a _ClosureWrapper so that it can be invoked
 * consistently, else return the value.
 *
 * TODO(justin): Unwrap at the top level for bindings? How do you unwrap an
 * _InvokeWrapper? We'd need to generate the closure.
 */
dynamic _wrap(v) =>
    (v is Function && v is! _FunctionWrapper) ? new _ClosureWrapper(v) : v;

abstract class _FunctionWrapper {}

class _ClosureWrapper implements _FunctionWrapper {
  final Function f;
  _ClosureWrapper(this.f);
  dynamic call(List args) => Function.apply(f, args, null);
}

class _InvokeWrapper implements _FunctionWrapper {
  final InstanceMirror mirror;
  final Symbol symbol;
  _InvokeWrapper(this.mirror, this.symbol);
  dynamic call(List args) => mirror.invoke(symbol, args, null).reflectee;
}

class EvalException {
  final String message;
  EvalException(this.message);
  String toString() => "EvalException: $message";
}
