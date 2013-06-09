// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax;

import 'dart:html';
import 'package:mdv_observe/mdv_observe.dart';

import 'eval.dart';
import 'parser.dart';
import 'expression.dart';

class FancySyntax extends CustomBindingSyntax {

  Binding getBinding(model, String path, name, node) {
    if (path != null && path.isNotEmpty) {
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

  Binding(this._expr, this._model);

  get value => eval(_expr, target: _model);

  set value(v) {
    if (_isAssignable()) {

      notifyChange(new PropertyChangeRecord(_VALUE));
    }
  }

  getValueWorkaround(key) {
    if (key == _VALUE) return value;
  }

  bool _isAssignable() {
    // TODO(justin): dot, index and filter expressions, move to eval.dart?
    if (_expr is Identifier) return true;
  }
}
