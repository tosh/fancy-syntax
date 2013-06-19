// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax.eval;

import 'dart:async';
import 'dart:collection';
import 'dart:mirrors';

import 'package:mdv_observe/mdv_observe.dart';

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
Object eval(Expression expr, Scope scope) => observe(expr, scope)._value;


ExpressionObserver observe(Expression expr, Scope scope) {
  var observer = new ObserverBuilder(scope).visit(expr);
  new Updater(scope).visit(observer);
  return observer;
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

/**
 * A mapping of names to objects. Scopes contain a set of named [variables] and
 * a single [model] object (which can be thought of as the "this" reference).
 * Names are currently looked up in [variables] first, then the [model].
 *
 * Scopes can be nested by giving them a [parent]. If a name in not found in a
 * Scope, it will look for it in it's parent.
 */
class Scope extends Object {
  final Scope parent;
  final Object model;
  // TODO(justinfagnani): disallow adding/removing names
  final ObservableMap<String, Object> _variables;
  InstanceMirror __modelMirror;

  Scope({this.model, Map<String, Object> variables: const {}, this.parent})
      : _variables = new ObservableMap.from(variables);

  InstanceMirror get _modelMirror {
    if (__modelMirror != null) return __modelMirror;
    __modelMirror = reflect(model);
    return __modelMirror;
  }

  Object operator[](String name) {
    if (_variables.containsKey(name)) {
      return _variables[name];
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
      throw new EvalException("variable not found: $name in $hashCode");
    }
  }

  Object ownerOf(String name) {
    if (_variables.containsKey(name)) {
      return _variables;
    } else {
      var symbol = new Symbol(name);
      var classMirror = _modelMirror.type;
      if (classMirror.variables.containsKey(symbol) ||
          classMirror.getters.containsKey(symbol) ||
          classMirror.methods.containsKey(symbol)) {
        return model;
      }
    }
    if (parent != null) {
      return parent.ownerOf(name);
    }
  }
}

abstract class ExpressionObserver<E extends Expression> implements Expression {
  final E _expr;
  ExpressionObserver _parent;

  StreamSubscription _subscription;
  Object _value;

  StreamController _controller = new StreamController.broadcast();
  Stream get onUpdate => _controller.stream;

  ExpressionObserver(this._expr);

  Object get currentValue => _value;

  update(Scope scope) => _updateSelf(scope);

  _updateSelf(Scope scope) {}

  _invalidate(Scope scope) {
    _observe(scope);
    if (_parent != null) {
      _parent._invalidate(scope);
    }
  }

  _observe(Scope scope) {
    // unobserve last value
    if (_subscription != null) {
      _subscription.cancel();
      _subscription = null;
    }

    var _oldValue = _value;

    // evaluate
    _updateSelf(scope);

    if (!identical(_value, _oldValue)) {
      _controller.add(_value);
    }
  }

  String toString() => _expr.toString();
}

class Updater extends RecursiveVisitor<ExpressionObserver> {
  final Scope scope;

  Updater(this.scope);

  visitExpression(ExpressionObserver e) {
    e._observe(scope);
  }

  visitInExpression(InObserver c) {
    visit(c.right);
    visitExpression(c);
  }
}

class ObserverBuilder extends Visitor {
  final Scope scope;
  final Queue parents = new Queue();

  ObserverBuilder(this.scope);

  visitEmptyExpression(EmptyExpression e) => new EmptyObserver(e);

  visitParenthesizedExpression(ParenthesizedExpression e) => visit(e.child);

  visitInvoke(Invoke i) {
    var receiver = visit(i.receiver);
    var args = (i.arguments == null)
        ? null
        : i.arguments.map((a) => visit(a)).toList(growable: false);
    var invoke =  new InvokeObserver(i, receiver, args);
    receiver._parent = invoke;
    if (args != null) args.forEach((a) => a._parent = invoke);
    return invoke;
  }

  visitLiteral(Literal l) => new LiteralObserver(l);

  visitIdentifier(Identifier i) => new IdentifierObserver(i);

  visitBinaryOperator(BinaryOperator o) {
    var left = visit(o.left);
    var right = visit(o.right);
    var binary = new BinaryObserver(o, left, right);
    left._parent = binary;
    right._parent = binary;
    return binary;
  }

  visitUnaryOperator(UnaryOperator o) {
    var expr = visit(o.child);
    var unary = new UnaryObserver(o, expr);
    expr._parent = unary;
    return unary;
  }

  visitInExpression(InExpression i) {
    // don't visit the left. It's an identifier, but we don't want to evaluate
    // it, we just want to add it to the comprehension object
    var left = visit(i.left);
    var right = visit(i.right);
    var inexpr = new InObserver(i, left, right);
    right._parent = inexpr;
    return inexpr;
  }
}

class EmptyObserver extends ExpressionObserver<EmptyExpression>
    implements EmptyExpression {

  EmptyObserver(EmptyExpression value) : super(value);

  _updateSelf(Scope scope) {
    _value = scope.model;
    // TODO(justin): listen for scope.model changes?
  }

  accept(Visitor v) => v.visitEmptyExpression(this);
}

class LiteralObserver extends ExpressionObserver<Literal> implements Literal {

  LiteralObserver(Literal value) : super(value);

  dynamic get value => _expr.value;

  _updateSelf(Scope scope) {
    _value = _expr.value;
  }

  accept(Visitor v) => v.visitLiteral(this);
}

class IdentifierObserver extends ExpressionObserver<Identifier>
    implements Identifier {

  IdentifierObserver(Identifier value) : super(value);

  dynamic get value => _expr.value;

  _updateSelf(Scope scope) {
    _value = scope[_expr.value];

    var owner = scope.ownerOf(_expr.value);
    if (owner is Observable) {
      _subscription = (owner as Observable).changes.listen(
          (List<ChangeRecord> changes) {
            var symbol = new Symbol(_expr.value);
            if (changes.any((c) => c.changes(symbol))) {
              _invalidate(scope);
            }
          });
    }
  }

  accept(Visitor v) => v.visitIdentifier(this);
}

class ParenthesizedObserver extends ExpressionObserver<ParenthesizedExpression>
    implements ParenthesizedExpression {
  final ExpressionObserver child;

  ParenthesizedObserver(ExpressionObserver expr, this.child) : super(expr);


  _updateSelf(Scope scope) {
    _value = child._value;
  }

  accept(Visitor v) => v.visitParenthesizedExpression(this);
}

class UnaryObserver extends ExpressionObserver<UnaryOperator>
    implements UnaryOperator {
  final ExpressionObserver child;

  UnaryObserver(UnaryOperator expr, this.child) : super(expr);

  String get operator => _expr.operator;

  _updateSelf(Scope scope) {
    var f = _UNARY_OPERATORS[_expr.operator];
    // TODO(justin): type coercion
    _value = f(child._value);
  }

  accept(Visitor v) => v.visitUnaryOperator(this);
}

class BinaryObserver extends ExpressionObserver<BinaryOperator>
    implements BinaryOperator {

  final ExpressionObserver left;
  final ExpressionObserver right;

  BinaryObserver(BinaryOperator expr, this.left, this.right)
      : super(expr);

  String get operator => _expr.operator;

  _updateSelf(Scope scope) {
    var f = _BINARY_OPERATORS[_expr.operator];
    // TODO(justin): type coercion
    _value = f(left._value, right._value);
  }

  accept(Visitor v) => v.visitBinaryOperator(this);

}

class InvokeObserver extends ExpressionObserver<Invoke> implements Invoke {
  final ExpressionObserver receiver;
  List<ExpressionObserver> arguments;

  InvokeObserver(Expression expr, this.receiver, [this.arguments])
      : super(expr);

  bool get isGetter => _expr.isGetter;

  String get method => _expr.method;

  _updateSelf(Scope scope) {
    var args = (arguments == null)
        ? []
        : arguments.map((a) => a._value)
            .toList(growable: false);
    var receiverValue = receiver._value;
    if (_expr.method == null) {
      if (_expr.isGetter) {
        _value = receiverValue;
      } else {
        assert(receiverValue is Function);
        _value = call(receiverValue, args);
      }
    } else {
      // special case [] because we don't need mirrors
      if (_expr.method == '[]') {
        assert(args.length == 1);
        _value = receiverValue[args[0]];
        // TODO: listen to map changes
      } else {
        var mirror = reflect(receiverValue);
        var symbol = new Symbol(_expr.method);
        _value = (_expr.isGetter)
            ? mirror.getField(symbol).reflectee
            : mirror.invoke(symbol, args, null).reflectee;
        if (_value is Observable) {
          _subscription = (_value as Observable).changes.listen(
              (List<ChangeRecord> changes) {
                if (changes.any((c) => c.changes(symbol))) {
                  _invalidate(scope);
                }
              });
        }
      }
    }
  }

  accept(Visitor v) => v.visitInvoke(this);
}

class InObserver extends ExpressionObserver<InExpression>
    implements InExpression {
  IdentifierObserver left; // not an observer because we don't want to lookup the ident
  ExpressionObserver right;

  InObserver(Expression expr, this.left, this.right) : super(expr);

  _updateSelf(Scope scope) {
    Identifier identifier = left;
    var iterable = right._value;
    if (iterable is! Iterable) {
      throw new EvalException("right side of 'in' is not an iterator");
    }
    _value = new Comprehension(identifier.value, iterable);
  }

  accept(Visitor v) => v.visitInExpression(this);
}

call(dynamic receiver, List args) {
  if (receiver is Method) {
    return receiver.mirror.invoke(receiver.symbol, args, null).reflectee;
  } else {
    return Function.apply(receiver, args, null);
  }
}

/**
 * A comprehension declaration ("a in b").
 */
class Comprehension {
  final String identifier;
  final Iterable iterable;
  Comprehension(this.identifier, this.iterable);
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
