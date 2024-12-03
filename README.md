# Advent of Code in Zig

Implementing [Advent of Code 2024](https://adventofcode.com/2024) in Zig.

**Disclaimer:** This is the first time I've written Zig so it's probably not using best practices and whatnot. Any helpful feedback welcome 😎

## Getting started

First, [Install zig](https://ziglang.org/learn/getting-started/), e.g. `brew install zig`.

To run a particular day challenge:

```bash
# In debug mode
zig run src/main.zig -- <day n#>

# In release mode
zig build -Doptimize=ReleaseFast
./zig-out/bin/aoc24 <day n#>
```

## Benchmarks

Benchmarks from running on my M3 Pro:

| Challenge | Status | Time (mean ± σ) | Range (min … max) | Details |
| --------- | ------ | --------------- | ----------------- | ------- |
|        #1 |   Done | 8.1 ms ± 0.5 ms |  3.5 ms … 22.3 ms | User: 2.0 ms, System: 5.7 ms, Runs: 353 |
|        #2 |   Todo |                 |                   | |
|        #3 |   Todo |                 |                   | |
|        #4 |   Todo |                 |                   | |
|        #5 |   Todo |                 |                   | |
|        #6 |   Todo |                 |                   | |
|        #7 |   Todo |                 |                   | |
|        #8 |   Todo |                 |                   | |
|        #9 |   Todo |                 |                   | |
|       #10 |   Todo |                 |                   | |
|       #11 |   Todo |                 |                   | |
|       #12 |   Todo |                 |                   | |
|       #13 |   Todo |                 |                   | |
|       #14 |   Todo |                 |                   | |
|       #15 |   Todo |                 |                   | |
|       #16 |   Todo |                 |                   | |
|       #17 |   Todo |                 |                   | |
|       #18 |   Todo |                 |                   | |
|       #19 |   Todo |                 |                   | |
|       #20 |   Todo |                 |                   | |
|       #21 |   Todo |                 |                   | |
|       #22 |   Todo |                 |                   | |
|       #23 |   Todo |                 |                   | |
|       #24 |   Todo |                 |                   | |
|       #25 |   Todo |                 |                   | |

(Note: benchmarks run using `hyperfine -N --warmup 5 './zig-out/bin/aoc24 <day n#>'`.)
