// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax;

import 'dart:html';
import 'dart:collection';
import 'package:mdv_observe/mdv_observe.dart';

import 'assign.dart';
import 'eval.dart';
import 'parser.dart';
import 'expression.dart';
import 'visitor.dart';

class FancySyntax extends CustomBindingSyntax {

  Binding getBinding(model, String path, name, node) {
    if (path != null) {
      var expr = new Parser(path).parse();
      return new Binding(expr, model);
    } else {
      return null;
    }
  }

}

/*
 * This class needs to eventually find all simple paths within an expression
 * and bind to each on independently so that change observation can work. Simple
 * paths can contain: dots, index operators with const arguments, and filters.
 *
 * 2-way bindings will be restricted to expressions with a single simple path
 * where all filters are 2-way transformers.
 */
class Binding extends Object with ObservableMixin {
  static const _VALUE = const Symbol('value');

  final Expression _expr;
  final _model;

  Binding(Expression expr, this._model)
    : _expr = expr {
    print("Binding: $expr");
  }

  get value {
    try {
      var value = eval(_expr, target: _model);
    } on EvalException catch (e) {
      // silently swallow binding errors
    }
    return value;
  }

  set value(v) {
    try {
      assign(_expr, _model, v);
      notifyChange(new PropertyChangeRecord(_VALUE));
    } on EvalException catch (e) {
      // silently swallow binding errors
    }
  }

  getValueWorkaround(key) {
    if (key == _VALUE) return value;
  }

  setValueWorkaround(key, v) {
    if (key == _VALUE) value = v;
  }

}
