// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax.eval;

import 'dart:collection';
import 'dart:mirrors';

import 'expression.dart';
import 'filter.dart';
import 'visitor.dart';
import 'parser.dart';

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
  '|':  (a, f) {
    if (f is Transformer) return f.forward(a);
    if (f is Filter) return f(a);
    throw new EvalException("Filters must be a one-argument function.");
  }
};

final _UNARY_OPERATORS = {
  '+': (a) => a,
  '-': (a) => -a,
  '!': (a) => !a,
};

/**
 * Evaluation [expr] in the context of [scope].
 */
Object eval(Expression expr, Scope scope) {
  var visitor = new _MirrorEvaluator(scope);
  return visitor.visitExpression(expr);
}

/**
 * Assign [value] to the variable or field referenced by [expr] in the context
 * of [scope].
 *
 * [expr] must be an /assignable/ expression, it must not contain
 * operators or function invocations, and any index operations must use a
 * literal index.
 */
void assign(Expression expr, Object value, Scope scope) {

  notAssignable() =>
      throw new EvalException("Expression is not assignable: $expr");

  Expression expression;
  var property;
  bool isIndex = false;
  var filters = <Expression>[]; // reversed order for assignment

  while (expr is BinaryOperator && expr.operator == '|') {
    filters.add(expr.right);
    expr = expr.left;
  }

  if (expr is Identifier) {
    expression = empty();
    property = expr.value;
  } else if (expr is Invoke) {
    expression = expr.receiver;
    if (expr.method == '[]') {
      if (expr.arguments[0] is! Literal) notAssignable();
      Literal l = expr.arguments[0];
      property = l.value;
      isIndex = true;
    } else if (expr.method != null) {
      if (expr.arguments != null) notAssignable();
      property = expr.method;
    } else {
      notAssignable();
    }
  } else {
    notAssignable();
  }

  // transform the values backwards through the filters
  for (var filterExpr in filters) {
    var filter = eval(filterExpr, scope);
    if (filter is! Transformer) {
      throw new EvalException("filter must implement Transformer: $filterExpr");
    }
    value = filter.reverse(value);
  }
  // make the assignment
  var o = eval(expression, scope);
  if (o == null) throw new EvalException("Can't assign to null: $expression");
  if (isIndex) {
    o[property] = value;
  } else {
    reflect(o).setField(new Symbol(property), value);
  }
}

class Comprehension {
  final String identifier;
  final Iterable iterable;
  Comprehension(this.identifier, this.iterable);
}

/**
 * A mapping of names to objects. Scopes contain a set of named [variables] and
 * a single [model] object (which can be thought of as the "this" reference).
 * Names are currently looked up in [variables] first, then the [model].
 *
 * Scopes can be nested by giving them a [parent]. If a name in not found in a
 * Scope, it will look for it in it's parent.
 */
class Scope {
  final Scope parent;
  final Object model;
  final Map<String, Object> variables;
  InstanceMirror __modelMirror;

  Scope({this.model, Map<String, Object> variables, this.parent})
      : variables = (variables == null) ? {} : variables;

  InstanceMirror get _modelMirror {
    if (__modelMirror != null) return __modelMirror;
    __modelMirror = reflect(model);
    return __modelMirror;
  }

  Object operator[](String name) {
    if (variables.containsKey(name)) {
      return variables[name];
    } else if (model != null) {
      var symbol = new Symbol(name);
      var classMirror = _modelMirror.type;
      if (classMirror.variables.containsKey(symbol) ||
          classMirror.getters.containsKey(symbol)) {
        return _modelMirror.getField(symbol).reflectee;
      } else if (classMirror.methods.containsKey(symbol)) {
        return new Method(_modelMirror, symbol);
      }
    }
    if (parent != null) {
      return parent[name];
    } else {
      throw new EvalException("variable not found: $name");
    }
  }
}

/**
 * Evaluates an expression.
 */
class _MirrorEvaluator extends Visitor {
  final Scope scope;

  _MirrorEvaluator(this.scope);

  visitExpression(Expression e) => visit(e);

  visitEmptyExpression(EmptyExpression e) => scope.model;

  visitParenthesizedExpression(ParenthesizedExpression e) => visit(e.expr);

  visitInExpression(InExpression c) {
    Identifier identifier = c.left;
    var iterable = visit(c.right);
    if (iterable is! Iterable) {
      throw new EvalException("right side of 'in' is not an iterator");
    }

    return new Comprehension(identifier.value, iterable);
  }

  visitInvoke(Invoke i) {
    var args = (i.arguments == null)
        ? []
        : i.arguments.map((a) => a.accept(this)).toList(growable: false);
    var receiver = visit(i.receiver);
    if (i.method == null) {
      if (i.isGetter) {
        return receiver;
      } else {
        assert(receiver is Function);
        return _call(receiver, args);
      }
    } else {
      // special case [] because we don't need mirrors
      if (i.method == '[]') {
        assert(args.length == 1);
        return receiver[args[0]];
      } else {
        var mirror = reflect(receiver);
        return (i.isGetter)
            ? mirror.getField(new Symbol(i.method)).reflectee
            : mirror.invoke(new Symbol(i.method), args, null).reflectee;
      }
    }
  }

  // This will only be called at the top level of an expression, all other
  // identifiers will be stored as the method of an Invoke node.
  visitIdentifier(Identifier e) => scope[e.value];

  visitLiteral(Literal l) => l.value;

  visitBinaryOperator(BinaryOperator o) {
    var left = visit(o.left);
    var right = visit(o.right);
    var f = _BINARY_OPERATORS[o.operator];
    // TODO(justin): type coercion
    return f(left, right);
  }

  visitUnaryOperator(UnaryOperator o) {
    var e = visit(o.expr);
    var f = _UNARY_OPERATORS[o.operator];
    // TODO(justin): type coercion
    return f(e);
  }
}

_call(dynamic receiver, List args) {
  if (receiver is Method) {
    return receiver.mirror.invoke(receiver.symbol, args, null).reflectee;
  } else {
    return Function.apply(receiver, args, null);
  }
}

/**
 * A method on a model object in a [Scope].
 */
class Method { //implements _FunctionWrapper {
  final InstanceMirror mirror;
  final Symbol symbol;

  Method(this.mirror, this.symbol);

  dynamic call(List args) => mirror.invoke(symbol, args, null).reflectee;
}

class EvalException implements Exception {
  final String message;
  EvalException(this.message);
  String toString() => "EvalException: $message";
}
