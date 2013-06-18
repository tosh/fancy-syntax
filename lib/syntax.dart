// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax;

import 'dart:html';
import 'dart:collection';
import 'package:mdv_observe/mdv_observe.dart';

import 'eval.dart';
import 'parser.dart';
import 'expression.dart';
import 'visitor.dart';



class FancySyntax extends CustomBindingSyntax {
  static final List<String> _tagsWithTemplates = ['option', 'caption',
      'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th','thead', 'tr'];

  static final String _allTemplatesSelectors = 'template, option[template], ' +
      _tagsWithTemplates.map((t) => "$t[template]").join(", ");

  final Map<String, Object> globals;

  FancySyntax({Map<String, Object> globals})
      : globals = (globals == null) ? new Map<String, Object>() : globals;

  _Binding getBinding(model, String path, name, node) {
    if (path != null) {
      if (model is! Scope) {
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

/*
 * This class needs to eventually find all simple paths within an expression
 * and bind to each on independently so that change observation can work. Simple
 * paths can contain: dots, index operators with const arguments, and filters.
 *
 * 2-way bindings will be restricted to expressions with a single simple path
 * where all filters are 2-way transformers.
 */
class _Binding extends Object with ObservableMixin {
  static const _VALUE = const Symbol('value');

  final Scope _scope;
  final Expression _expr;

  _Binding(this._expr, this._scope);

  get value {
    try {
      var v = eval(_expr, _scope);
      if (v is Comprehension) {
        return v.iterable.map((i) {
          var childScope = new Scope(parent: _scope);
          childScope.variables[v.identifier] = i;
          return childScope;
        }).toList(growable: false);
      } else {
        return v;
      }
    } on EvalException catch (e) {
      // silently swallow binding errors
    }
  }

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
