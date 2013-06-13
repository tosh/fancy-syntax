// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax.assign;

import 'dart:collection';
import 'dart:mirrors';

import 'eval.dart';
import 'expression.dart';
import 'filter.dart';
import 'visitor.dart';

void assign(Expression expr, Object target, Object value,
            {Map<String, Object> scope}) {

  notAssignable() =>
      throw new EvalException("Expression is not assignable: $expr");

  Expression expression;
  dynamic property;
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
    var filter = eval(filterExpr, target: target, scope: scope);
    if (filter is! Transformer) {
      throw new EvalException("filter must implement Transformer");
    }
    value = filter.reverse(value);
  }
  // make the assignment
  var o = eval(expression, target: target, scope: scope);
  assert(o != null);
  if (isIndex) {
    o[property] = value;
  } else {
    var mirror = reflect(o);
    mirror.setField(new Symbol(property), value);
  }
}
