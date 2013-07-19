fancy-syntax
============

Fancy Syntax is an expressive custom binding syntax for [MDV][mdv] (Model-driven Views) templates in Dart.

Fancy Syntax allows you to write complex binding expressions, with property access, function invocation, list/map indexing, and two-way filtering like `{{ person.title + " " + person.getFullName() | upppercase }}`.

[mdv]: http://www.polymer-project.org/platform/mdv.html

##Overview

### MDV
MDV allows you to define templates directly in HTML that are rendered by the browser into the DOM. Templates are bound to a data model, and changes to the data are automatically reflected in the DOM, and changes in HTML inputs are assigned back into the model. The template and model are bound together via binding expressions that are evaluated against the model. These binding expressions are placed in double-curly-braces, or "mustaches".

Example:

    <template>
      <p>Hello {{ person.name }}</p>
    </template>

MDV includes a very basic binding syntax which only allows a series of dot-separate property names.

### Custom Binding Syntaxes

While MDV's built-in syntax is very basic, it does allow custom syntaxes to be installed and used. A custom syntax can interpret the contents of mustaches however it likes. Fancy Syntax is such a custom binding syntax.

Example:

    <template syntax="fancy">
      <p>Hello {{ person.title + " " + person.getFullName() | upppercase }}</p>
    </template>

## Usage

### Installing from Pub

Add the following to your pubspec.yaml file:

    dependencies:
      fancy_syntax: 0.0.3

Then import syntax.dart:

    import 'package:fancy_syntax/syntax.dart';

### Registering a Custom Syntax

Custom syntaxes must be installed and associated with a syntax name before they can be used. In your `main()` function, first initialize MDV, then create a new FancySyntax object and associate it with a name, like "fancy". Any template element that has a syntax attribute set to "fancy" will then use the FancySyntax instance to interpret binding expressions.

    import 'dart:html';
    import 'package:mdv/mdv.dart' as mdv;
    import 'package:fancy_syntax:syntax.dart';

    main() {
      mdv.initialize();
      TemplateElement.syntax['fancy'] = new FancySyntax();
    }

### Registering Top-Level Variables

Before a top-level variable can be used, it must be registered. The FancySyntax constructor takes a map of named values to use as variables.

    main() {
      var globals = {
        'uppercase': (String v) => v.toUpperCase(),
        'app_id': 'fancy_app_123',
      };
      TemplateElement.syntax['fancy'] = new FancySyntax(globals: globals);
    }

Once the syntax is intalled it can be used in templates by specifying the "syntax" attribute.

## Features

### The Model and Scope

Fancy Syntax allows binding to more than just the model assigned to a template instance. Top-level variables can be defined so that you can use filters, global variables and constants, functions, etc. These variables and the model are held together in a container called a Scope. Scopes can be nested, which happens when template tags are nested.

### Two-way Bindings

Bindings can be used to modify the data model based on events in the DOM. The most common case is to bind an &lt;input&gt; element's value field to a model property and have the property update when the input changes. For this to work, the binding expression must be "assignable". Only a subset of expressions are assignable. Assignable expressions cannot contain function calls, operators, and any index operator must have a literal argument. Assignable expressions can contain filter operators as long as all the filters are two-way transformers.

Some restrictions may be relaxed further as allowed.

Assignable Expressions:

 * `foo`
 * `foo.bar`
 * `items[0].description`
 * `people['john'].name`
 * `product.cost | convertCurrency('ZWD')` where `convertCurrency` evaluates to a Tranformer object.

Non-Assignable Expressions:

 * `a + 1`
 * `!c`
 * `foo()`
 * `person.lastName | uppercase` where `uppercase` is a filter function.

### Null-Safety

Expressions are generally null-safe. If an intermediate expression yields `null` the entire expression will return null, rather than throwing an exception. Property access, method invocation and operators are null-safe. Passing null to a function that doesn't handle null will not be null safe.

### Streams

Fancy Syntax has experimental support for binding to streams, and when new values are passed to the stream, the template updates. The feature is not fully implemented yet.

See the examples in /example/streams for more details.

## Syntax

### Property Access

Properties on the model and in the scope are looked up via simple property names, like `foo`. Property names are looked up first in the top-level variables, next in the model, then recursively in parent scopes. Properties on objects can be access with dot notation like `foo.bar`.

Note, there is currently no "this" property to differentiate between top-level variables and model properties, so the top-level variables will always win.

### Literals

Fancy Syntax supports number, boolean, string, and map literals. Strings can use either single or double quotes.

 * Numbers: `1`, `1.0`
 * Booleans: `true`, `false`
 * Strings: `'abc'`, `"xyz"`
 * Maps: `{ 'a': 1, 'b': 2 }`

List literals are planned: https://github.com/dart-lang/fancy-syntax/issues/9

### Functions and Methods

If a property is a function in the scope, a method on the model, or a method on an object, it can be invoked with standard function syntax. Functions and Methods can take arguments. Named arguments are not supported. Arguments can be literals or variables.

Examples:

 * Top-level function: `myFunction()`
 * Top-level function with arguments: `myFunction(a, b, 42)`
 * Model method: `aMethod()`
 * Method on nested-property: `a.b.anotherMethod()`

### Operators

Fancy Syntax supports the following binary and unary operators:

 * Arithmetic operators: +, -, *, /, %, unary + and -
 * Comparison operators: ==, !=, <=, <, >, >=
 * Boolean operators: &&, ||, unary !

Expressions do not support bitwise operators such as &, |, << and >>, or increment/decrement operators (++ and --)

### List and Map Indexing

List and Map like objects can be accessed via the index operator: []

Examples:

 * `items[2]`
 * `people['john']`

Unlike JavaScript, list and map contents are not generally available via property access. That is, the previous examples are not equivalent to `items.2` and `people.john`. This ensures that access to properties and methods on Lists and Maps is preserved.

### Filters and Transformers

A filter is a function that transforms a value into another, used via the pipe syntax: `value | filter` Any function that takes exactly one argument can be used as a filter.

Example:

If `person.name` is "John", and a top-level function named `uppercase` has been registered, then `person.name | uppercase` will have the value "JOHN".

The pipe syntax is used rather than a regular function call so that we can support two-way bindings through transformers. A transformer is a filter that has an inverse function. Transformers must extend or implement the `Transformer` class, which has `forward()` and `reverse()` methods.

### Repeating Templates

A template can be repeated by using the "repeat" attribute with a binding. The binding can either evaluate to an Iterable, in which case the template is instantiated for each item in the iterable and the model of the instance is set to the item, or the binding can be a "in" iterator expression, in which case a new variable is added to each scope.

The following examples produce the same output.

Evaluate to an iterable:

    <template repeat="{{ items }}">
      <div>{{ }}</div>
    </template>


"in" expression:

    <template repeat="{{ item in items }}">
      <div>{{ item }}</div>
    </template>

## Status

The syntax implemented is experimental and subject to change, in fact, it **will** change soon. The goal is to be compatible with Polymer's binding syntax. We will announce breaking changes on the web-ui@dartlang.org mailing list.

Please [file issues on Github](https://github.com/dart-lang/fancy-syntax/issues) for any bugs you find or for feature requests.

You can discuss Fancy Syntax on the [web-ui@dartlang.org](https://groups.google.com/a/dartlang.org/forum/#!forum/web-ui) mailing list.
