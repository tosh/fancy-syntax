// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fancy_syntax.visitor;

import 'expression.dart';
import 'parser.dart';

abstract class Visitor {

  visitExpression(Expression e);
  visitEmptyExpression(EmptyExpression e);
  visitParenthesizedExpression(ParenthesizedExpression e);
  visitInvoke(Invoke i);
  visitLiteral(Literal l);
  visitIdentifier(Identifier i);
  visitBinaryOperator(BinaryOperator o);
  visitUnaryOperator(UnaryOperator o);

}
