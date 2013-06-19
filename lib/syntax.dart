// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax;

import 'dart:html';
import 'dart:collection';
import 'package:mdv_observe/mdv_observe.dart';

import 'eval.dart';
import 'expression.dart';
import 'parser.dart';
import 'visitor.dart';

class FancySyntax extends CustomBindingSyntax {

  final Map<String, Object> globals;

  FancySyntax({Map<String, Object> globals})
      : globals = (globals == null) ? new Map<String, Object>() : globals;

  _Binding getBinding(model, String path, name, node) {
    if (path != null) {
      if (path.isEmpty) {
        // avoid creating an unneccesary scope for the top-level template
        return null;
      } else if (model is! Scope) {
        model = new Scope(model: model, variables: globals);
      }
      var expr = new Parser(path).parse();
      return new _Binding(expr, model);
    } else {
      return null;
    }
  }

  getInstanceModel(Element template, model) {
    if (model is! Scope) {
      var _scope = new Scope(model: model, variables: globals);
      return _scope;
    }
    return model;
  }

  getInstanceFragment(Element template) => template.createInstance();
}

class _Binding extends Object with ObservableMixin {
  static const _VALUE = const Symbol('value');

  final Scope _scope;
  final ExpressionObserver _expr;
  var _value;

  _Binding(Expression expr, Scope scope)
      : _expr = observe(expr, scope),
        _scope = scope {
    _expr.onUpdate.listen(_setValue);
    _setValue(_expr.currentValue);
  }

  _setValue(v) {
    if (v is Comprehension) {
      _value = v.iterable.map((i) {
        var vars = new Map();
        vars[v.identifier] = i;
        Scope childScope = new Scope(parent: _scope, variables: vars);
        return childScope;
      }).toList(growable: false);
    } else {
      _value = v;
    }
    notifyChange(new PropertyChangeRecord(_VALUE));
  }

  get value => _value;

  set value(v) {
    try {
      assign(_expr, v, _scope);
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
