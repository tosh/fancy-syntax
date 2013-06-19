// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library all_tests;

import 'package:unittest/html_enhanced_config.dart';

import 'eval_test.dart' as eval;
import 'parser_test.dart' as parser;
import 'tokenizer_test.dart' as tokenizer;

main() {
  useHtmlEnhancedConfiguration();

  tokenizer.main();
  parser.main();
  eval.main();
}
