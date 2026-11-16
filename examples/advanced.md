---
title: Advanced programming with Jennifer
author: mplx
date: 2026-11
theme: ivy
ratio: 16:9
transition: zoom
description: Advanced programming with the Jennifer programming language: concurrency with spawn, tasks and channels, try/catch and error kinds, profiling, when values are copied or borrowed, and performance tuning. Based on Jennifer 0.26.0.
subject: Concurrency, errors, profiling and performance in Jennifer 0.26.0
keywords: jennifer, programming language, concurrency, spawn, channels, error handling, try catch, profiler, memory, value semantics, borrowing, performance tuning
lang: en
---

# Advanced programming with Jennifer

Concurrency, errors, profiling, memory and speed.

Based on **Jennifer 0.26.0**, November 2026.

<!-- notes:
The classroom talk showed how Jennifer explains itself. This one is for people
who already write it: how to run work in parallel, how to handle failure by
kind, and how to find and fix the slow part of a program. Every number on these
slides was measured with Jennifer 0.26.0 on an 8-core laptop; your figures will
differ, the shapes will not.
-->

---

## spawn: run work in parallel

```jennifer
def tasks as list of task of int init [];
for (def n in 1..5) {
    $tasks[] = spawn { return work($n); };
}
def results as list of int init task.waitAll($tasks);
```

```text
serial 370 ms, spawned 122 ms, same: true
```

`spawn` returns a `task of T` at once; `task.waitAll` keeps list order.

<!-- notes:
Four CPU-bound jobs, first one after the other, then each in its own spawn.
On eight cores the spawned version takes a third of the time and gives the same
list, in the same order, whatever order the tasks finished in. The body is just
a block with a return. There is no thread object, no pool to configure.
-->

---

## A spawn gets its own copy

```jennifer
def xs as list of int init [1, 2, 3];
def t as task of int init spawn {
    return $xs[0] + $xs[1] + $xs[2];
};
$xs[] = 99;
io.printf("%d %d\n", task.wait($t), len($xs));   # 6 4
```

No shared memory, no locks: data races are impossible by construction.

<!-- notes:
The spawn captures its surroundings by deep copy at the moment it starts. The
parent appends 99 afterwards; the task still sees three elements and returns 6.
That is the same value-semantics rule as everywhere else in Jennifer, reused
for concurrency. The price is the copy itself, which is proportional to what
the spawn captures: keep spawn bodies small and pass what they need.
-->

---

## Channels stream values between tasks

```jennifer
def ch as channel of int init channel.make(4);
def producer as task of int init spawn {
    for (def n in 1..6) { channel.send($ch, $n * $n); }
    channel.close($ch);
    return 0;
};
def sum as int init 0;
while (true) {
    # recv throws once the channel is closed and drained
    try { $sum = $sum + channel.recv($ch); } catch (e) { break; }
}
```

<!-- notes:
A task gives one result; a channel gives a stream. The channel has a capacity
of four, so the producer runs ahead by at most four values and then waits. Each
value is copied into the channel, so producer and consumer still share nothing.
When the producer closes the channel, the consumer reads what is left and then
gets an error, which ends the loop. The sum of squares from one to five is 55.
-->

---

## Cancellation and deadlines

```jennifer
task.cancel($worker);              # worker catches kind "cancelled"
try {
    task.waitTimeout($slow, 200);  # give up after 200 ms
} catch (e) {
    io.printf("gave up: %s\n", $e.kind);   # timeout
    task.cancel($slow);
    task.discard($slow);
}
```

```text
worker stopped: cancelled after 3 rounds
gave up: timeout
```

<!-- notes:
Cancellation is cooperative: `task.cancel` sets a flag, and the task sees a
catchable error of kind "cancelled" at its next checkpoint. A `time.sleep`, a
channel wait and a loop iteration are checkpoints, so the worker here stops
after three rounds and can still return what it has. `task.waitTimeout` bounds
a wait and throws kind "timeout". Note that `time.sleep` takes a Duration:
`time.sleep(100)` is an error that tells you to write
`time.fromMilliseconds(100)`.
-->

---

## try / catch: decide by kind

```jennifer
try {
    return json.decode($text);
} catch (e) {
    if ($e.kind == "limit") {
        io.printf("too big or too deep: %s\n", $e.message);
    } else {
        io.printf("%s: %s\n", $e.kind, $e.message);
    }
}
```

```text
runtime: json.decode: unexpected end of input at line 1, column 13
too big or too deep: json.decode: nesting exceeds 1000 levels at line 1, column 1001
```

<!-- notes:
Every error is a value with a kind and a message, and a catch decides what to
do by its kind. Here a malformed document and a hostile one (five thousand
opening brackets) fail differently: the second hits the decoder's nesting cap,
and every cap in Jennifer throws the same kind, "limit". The rule for real
code: branch on the kind, never on the message text. Messages are for people
and may change; kinds are the contract.
-->

---

## Error kinds you can rely on

| Kind | Means |
| --- | --- |
| `limit` | a size, count or depth cap was reached |
| `timeout` | a deadline passed |
| `closed` | the other side closed, also mid-read |
| `cancelled` | the task was cancelled |
| `net` | a socket failed: `net.NetError{reason, sent, replied}` |

Libraries with data to report throw a struct: `rest.HttpError` carries the
status, `smtp.SmtpError` the reply code.

<!-- notes:
These generic kinds mean the same thing in every library, so one catch handles
a cap or a timeout wherever it came from. Network failures carry a struct with
the reason (refused, reset, dns, tls, ...) and whether the request was sent,
which is exactly what a retry decision needs: retry only what was never sent.
Libraries whose servers report a status throw their own struct, so the status
is a field, not something parsed out of a message. A wrapper that rethrows
must pass these kinds on unchanged.
-->

---

## defer and errdefer: clean up on the way out

```jennifer
func setup(fail as bool) {
    defer io.printf("setup done\n");   # always
    io.printf("open\n");
    errdefer undo("open");             # only on error
    io.printf("reserve\n");
    errdefer undo("reserve");
    if ($fail) { throw Error{kind: "value", message: "no config"}; }
    return "ready";
}
```

- `setup(false)`: open, reserve, setup done, returns `"ready"`
- `setup(true)`: open, reserve, **undo reserve, undo open**, setup done, throws

<!-- notes:
There is no `finally` in Jennifer. Instead, `defer` schedules a call for when
the block exits, however it exits: return, break, throw or falling off the end.
Put it right after you acquire something, so the release sits next to the
acquire: `defer fs.close($f);`. `errdefer` is the undo half: it runs only when
an error is leaving the block. On success the opened and reserved resources
stay, and only "setup done" is printed. On failure the undo steps run newest
first, last-in first-out, then the defer, and the error still reaches the
caller. The arguments are evaluated at the defer line, so the call undoes what
existed at that point. Typical use: `errdefer net.close($c);` after a connect,
so a failed handshake closes the socket and a successful one keeps it open.
-->

---

## Measure first: jennifer profile

```text
$ jennifer profile concat.j
   HITS          SELF           CUM  POSITION
      1   33.861817ms  1.585271611s  concat.j:8:1
  20000  1.551409794s  1.551409794s  concat.j:9:5
      1    10.91819ms    78.20022ms  concat.j:13:1
  20000    67.28203ms    67.28203ms  concat.j:14:5
```

Two loops, 20,000 rounds each. One line takes 95% of the time.

<!-- notes:
Before changing anything, ask the profiler. It lists every statement with its
hit count, the time spent in the statement itself, and the time including what
it called. Both loops run twenty thousand times, but line 9 takes one and a
half seconds and line 14 sixty-seven milliseconds. Optimise the line the
profiler names, not the one you suspect.
-->

---

## Why `+` in a loop is slow

```jennifer
def out as string init "";
for (def i in 0..$n) {
    $out = $out + "line\n";    # copies all of $out, every round
}
```

| Lines | `+` in a loop | append, then join |
| --- | --- | --- |
| 20,000 | 976 ms | 68 ms |
| 40,000 | 4,872 ms | 101 ms |

Twice the lines, five times the time: quadratic.

<!-- notes:
Values are copied, not shared, so `$out + "line\n"` builds a new string that
contains a copy of everything so far. Round one copies five bytes, round twenty
thousand copies a hundred kilobytes; the total grows with the square of the
number of rounds. Doubling the input makes it five times slower, the signature
of a quadratic loop. The fix on the next slide is linear.
-->

---

## Append to a list, join once

```jennifer
def lines as list of string init [];
for (def i in 0..$n) {
    $lines[] = "line";            # grows in place: amortised O(1)
}
def out as string init strings.join($lines, "\n") + "\n";
```

- `$xs[] = item;` appends in place; `lists.push($xs, item)` builds a copy
- the same for `bytes`: append with `$b[] = byte;`
- must you use `+`? group the small part: `$out + ($k + ": " + $v + "\n")`

<!-- notes:
A list grows its own storage in place, so appending is constant time on
average, and the single join at the end touches every byte once. Same output,
68 instead of 976 milliseconds, and it stays linear as the input grows. If a
concatenation in a loop is unavoidable, put the small pieces in parentheses:
the chain then copies the large accumulator once instead of at every plus.
-->

---

## profile --allocs: what was copied

```jennifer
func total(xs as list of int) { ... }                   # reads only
func cellOf(rows as list of list of int, r as int, c as int) { ... }
func cell(m as Matrix, r as int, c as int) { ... }      # rows in a struct
```

```text
$ jennifer profile --allocs borrow.j
Eager copies - a def / assignment / parameter binding that deep-copied a compound value:
  COUNT     BYTES  TYPE                 POSITION
    300   3.5 GiB  list of list of int  borrow.j:32:22
```

Each was called 300 times. Only `cellOf` copied anything.

<!-- notes:
The allocation profile counts value copies by the line that made them. Three
helpers, each called three hundred times with a large argument. `total` only
reads its list, so the list is borrowed: no copy, no row in the report.
`cellOf` takes a list of lists, and nested collections are not borrowed yet,
so every call copies the whole matrix: three and a half gigabytes in total.
`cell` takes the same data wrapped in a struct, and a struct is borrowed.
-->

---

## Copied or borrowed?

- **Borrowed:** a parameter the function never writes, for `list`, `map`,
  `bytes` and structs
- **Updated in place:** `$grid = put($grid, x, y, v);` on a local, outside `try`
- **Copied every call:**
  - nested collections (`list of list`, `map of K to list`): wrap them in a struct
  - functions that use callbacks (`lists.map`, `sortBy`, ...) when the program has mutable globals
  - module calls, for values holding the module's own structs
- **Copied once:** a `spawn` snapshot, a `channel.send`

<!-- notes:
The rules behind the last slide. Assignment always means a copy you can change
freely, and the interpreter skips the copy wherever it can prove nobody would
notice: a read-only parameter, or a value passed in and assigned straight back.
The three gaps are where a helper in a hot loop goes quadratic, and the
allocation profile points at each of them by line. The struct wrapper is the
everyday fix; for callbacks, `lists.sort` on computed keys or `def const`
top-level state restores the borrow.
-->

---

## More tuning, from the docs

- **Hot calls out of the innermost loop:** inline or batch a helper called per
  element; a highlighter got 1.37x faster this way
- **Bytes work belongs in `binary`:** one native scan instead of a per-byte loop
- **Lift loop-invariant work** above the loop
- **Everywhere else, keep the small helpers:** call overhead only shows in the
  hottest loop, and the profiler tells you which one that is

<!-- notes:
A few more patterns from the performance guide. A function call has a fixed
cost, so a predicate called once per character adds up; moving it out of the
loop made a real syntax highlighter 37 percent faster with identical output.
Byte scanning should be one library call, not a loop. But all of this is for
the line the profiler names: everywhere else, readable small functions win.
-->

---

## Read more

- Concurrency: `docs/user-guide/concurrency.md`
- Performance: `docs/user-guide/performance.md`
- Profiler: `docs/technical/cli_profile.md`
- Language: [jennifer-lang.dev](https://jennifer-lang.dev/)
- This deck: Markdown, made with [cantrip](https://jennifer-language.github.io/cantrip/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
Everything here is in the user guide, with more examples. The figures are from
0.26.0; the milestones plan to close the three borrow gaps, so check the
performance guide for what has changed since.
-->
