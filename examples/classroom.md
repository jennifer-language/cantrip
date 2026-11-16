---
title: Jennifer for the classroom
author: mplx
date: 2026-11-16
theme: carbon
ratio: 16:9
transition: slide
description: Why the Jennifer programming language suits teaching and learning: a REPL, a readable grammar, token and AST dumps, a linter, a profiler, tests, and strict rules that turn mistakes into clear messages.
subject: Teaching and learning programming with Jennifer
keywords: jennifer, programming language, teaching, learning, classroom, education, interpreter, repl, lexer, parser, ast, linter, profiler, unit tests, strict typing
lang: en
---

# Jennifer for the classroom

![Jennifer](jennifer-logo.png)

A small language that shows its work.

> It also suits teaching and learning: an interactive REPL, an easy-to-read
> grammar, and token and AST dumps show what an interpreter does at each stage,
> plus a built-in linter and profiler and full test support. Its strict,
> explicit design (conditions must be bool, conversions are spelled out, names
> never shadow, errors are positioned) turns a mistake into a clear message
> instead of silent misbehavior.

<!-- notes:
This paragraph is from the introduction to Jennifer. The talk takes it apart
one claim at a time: one slide per claim, one small program per slide, and the
interpreter's real output underneath. Nothing here is mocked up.
The deck itself is made with cantrip, a slide tool written in Jennifer.
-->

---

## An interactive REPL

```text
$ jennifer repl
>>> def x as int init 6 * 7;
>>> $x;
42
>>> $x > 40;
true
```

Try a line, see the value, change it, try again.

<!-- notes:
Start where every beginner should start: one line at a time. The REPL keeps the
definitions you made, so a student builds a small program up step by step and
sees each value as it appears. There is no project to set up and no compile
step to explain on day one.
-->

---

## A grammar you can read aloud

```jennifer
use io;

def scores as list of int init [72, 88, 95];
def total as int init 0;
for (def s in $scores) {
    $total = $total + $s;
}
io.printf("average: %f|prec=1\n", $total / len($scores));
```

- `def name as type init value`: every variable says what it is
- `$name` reads a variable, so reading and declaring never look alike
- `/` is true division and gives a float (`85.0`); `//` floors to an int

<!-- notes:
Read the program out loud and it says what it does: define scores as a list of
int, initialised to these three numbers. Types are written out, so the question
"what is in this variable?" always has an answer on the page. The dollar sign
marks every read, which separates "this is a name I am creating" from "this is
a value I am using", a distinction beginners otherwise have to infer.
Division is the trap worth a minute: `/` always gives a float, `//` is floor
division. Print the average with `%d` and Jennifer refuses with "`%d` requires
int, got float" rather than silently dropping the fraction.
-->

---

## A linter that explains itself

```text
$ jennifer lint average.j
average.j:2:1: warning: unknown library `strngs` - did you mean `strings`? [L115]
average.j:5:5: warning: local `count` is declared but never used [L101]
average.j:11:5: warning: unreachable code after `return` [L102]
```

Built in, no setup. Every finding has a position, a reason and a rule code.

<!-- notes:
These are the mistakes students actually make: a typo in a library name, a
variable they meant to use and forgot, a line after the return that will never
run. The program still runs, so without a linter none of this is visible. Each
warning says where, what and why, and names its rule so it can be looked up.
The typo even gets a suggestion.
-->

---

## One format for everyone

```jennifer
func grade(points as int){if($points>=90){return "A";}
    return "B";}
```

```text
$ jennifer fmt grade.j
func grade(points as int) {
    if ($points >= 90) {
        return "A";
    }
    return "B";
}
```

`fmt -w` rewrites the file; `fmt -l` lists unformatted files and fails.

<!-- notes:
Every Jennifer program has one canonical layout, and `jennifer fmt` produces
it. That ends the style debates before they start: nobody argues about braces
or indentation, and a teacher grades the logic, not the whitespace. When every
submission, example and handout has the same shape, two solutions can be
compared line by line and the real difference stands out. `fmt -w` rewrites a
file in place; `fmt -l` lists the files that are not formatted and exits with
an error, so an exercise or a CI job can require formatted code the same way
it requires passing tests. Like the linter, the profiler and the test runner,
it is built in: one binary, no setup.
-->

---

## A profiler for "why is it slow?"

```text
$ jennifer profile fib.j
   HITS         SELF          CUM  POSITION
      1    558.476µs  78.105093ms  fib.j:8:1
  10945  62.804101ms  77.426766ms  fib.j:6:5
  21891   11.71869ms  14.742516ms  fib.j:3:5
  10946   3.023826ms   3.023826ms  fib.j:4:9
```

Hits and time for every statement: recursion you can count.

<!-- notes:
The classic recursive Fibonacci of 20. The profile shows the recursive line ran
10,945 times. That number is the lesson: exponential growth stops being an
abstract claim and becomes a figure next to a line number. Then write the loop
version, profile it again, and compare. `--allocs` does the same for copies of
values, for a lesson on memory.
-->

---

## Tests are part of the language

```jennifer
use testing;

func testBoundary() {
    testing.assertEqual(grade(75), "B");
}
```

```text
$ jennifer test grade_test.j
PASS testBoundary (0 ms)
FAIL testFail (0 ms)
     [assertion] grade_test.j:12:5 assertEqual: C != B
2 passed, 1 failed, 3 total
```

<!-- notes:
Any function named test-something in a test file is a test. No framework to
install, no runner to configure. A failing assertion reports the expected and
the actual value and the exact line. That makes test-first exercises practical
from the first week: hand out the tests, let students make them pass.
-->

---

## Conditions must be bool

```jennifer
def count as int init 3;
if ($count) {
    io.printf("non-empty\n");
}
```

```text
runtime error at cond.j:3:5: `if` condition must be bool, got int
  if ($count) {
      ^
```

Write the comparison you mean: `if ($count > 0)`.

<!-- notes:
In many languages a number, a string or an empty list quietly counts as true or
false, and every student eventually writes `if (x)` meaning something else.
Jennifer refuses: a condition is a bool. The fix is to write the comparison,
which is also the clearer program.
-->

---

## Conversions are spelled out

```jennifer
def total as int init 10;
def label as string init "total: " + $total;
```

```text
runtime error at conv.j:3:26: operator + requires numeric operands, got string and int
```

```jennifer
def label as string init "total: " + convert.toString($total);
```

<!-- notes:
Is "total: " + 10 a string, a number, or an error? Different languages answer
differently, and students learn the wrong rule from whichever one they met
first. Jennifer never converts behind your back. The conversion is a call you
can read, and the error tells you exactly which two types met.
-->

---

## Names never shadow

```jennifer
def name as string init "Ada";
func greet() {
    def name as string init "Grace";
}
```

```text
parse error at shadow.j:4:5: name "name" is already defined in an enclosing scope
      def name as string init "Grace";
      ^
```

<!-- notes:
Shadowing is a classic source of confusion: two variables with one name, and
the student cannot tell which one a line uses. In Jennifer a name means one
thing in a scope and everything inside it. This is caught before the program
runs at all: it is a parse error, not a surprise at run time.
-->

---

## Errors are positioned

Every message on these slides had the same shape:

- **file:line:column**: where it happened
- **what**: the rule that was broken, in plain words
- **the line itself**, with a caret under the spot

A mistake becomes a clear message instead of silent misbehavior.

<!-- notes:
Pull the thread together. Lexer, parser, linter, runtime and tests all report
the same way: position, reason, the source line, a caret. Students learn to
read one format and it works everywhere. And because the design is strict, the
mistakes that other languages let through quietly become one of these messages.
-->

---

## Tokens: what the lexer sees

```text
$ jennifer tokens hello.j
2:1   DEF
2:5   IDENT     "n"
2:7   AS
2:10  INT_TYPE
2:14  INIT
2:19  INT       "2"
2:21  PLUS
2:23  INT       "3"
2:24  SEMI
```

The first stage of every interpreter, with line and column for each token.

<!-- notes:
An optional look under the hood, for older students or a course on how
languages work; skip these two slides for beginners. This is the first exhibit. The source line
`def n as int init 2 + 3;` becomes a stream of tokens, each with its position.
Students can see that whitespace is gone, that `2` is an INT with the text "2",
and that every later error message gets its line and column from here.
-->

---

## The AST: what the parser builds

```text
$ jennifer ast hello.j
"init": {
  "type": "BinaryExpr",
  "line": 2, "col": 19,
  "op": "+",
  "left":  { "type": "IntLit", "value": 2 },
  "right": { "type": "IntLit", "value": 3 }
}
```

The same line as a tree, as JSON, ready for any tool to read.

<!-- notes:
The second stage. The flat token stream becomes a tree: a definition whose
initial value is a binary expression, plus, with two integer literals under it.
This is the moment precedence and nesting become visible. Because the dump is
JSON, students can write their own small tools over it: count nodes, find every
call, draw the tree. (The real output has a few more fields per node; they are
trimmed here.)
-->

---

## Try it

- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)
- Source: [github.com/jennifer-language/jennifer](https://github.com/jennifer-language/jennifer)
- This deck is Markdown, made with [cantrip](https://jennifer-language.github.io/cantrip/)

```sh
jennifer repl
```

<!-- notes:
Close with the invitation: install it, open the REPL, and type the first line
from the second slide. The deck you just saw is a Markdown file in cantrip's
repository, rendered by a program written in Jennifer.
-->
