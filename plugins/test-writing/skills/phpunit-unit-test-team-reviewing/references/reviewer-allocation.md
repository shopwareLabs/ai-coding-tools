# Reviewer Allocation & File Assignment

## Reviewer Count Formula

```
if N == 1: R = 3
else:      R = min(5, max(4, ceil(N * 3 / MAX_LOAD)))
```

`MAX_LOAD = 5` — target maximum files per reviewer. This is a soft target: when R is capped at 5, files per reviewer may exceed MAX_LOAD for large N.

| N (files) | R (reviewers) | Files/reviewer | Per-reviewer coverage |
|---|---|---|---|
| 1 | 3 | 1 | 100% |
| 2 | 4 | 1-2 | 50-100% |
| 3 | 4 | 2-3 | 67-100% |
| 5 | 4 | 3-4 | 60-80% |
| 7 | 5 | 4-5 | 57-71% |
| 10 | 5 | 6 | 60% |
| 15 | 5 | 9 | 60% |

## Round-Robin File Assignment

File at index `i` gets reviewers `[i % R, (i+1) % R, (i+2) % R]`.

Example with N=6, R=4:

| File | Reviewers |
|---|---|
| 0 | 0, 1, 2 |
| 1 | 1, 2, 3 |
| 2 | 2, 3, 0 |
| 3 | 3, 0, 1 |
| 4 | 0, 1, 2 |
| 5 | 1, 2, 3 |

## Properties

- Every file has exactly 3 reviewers
- No reviewer sees all files when N > R (for N <= R, some reviewers may still see all files due to the 3-of-R constraint)
- Adjacent files share 2 reviewers, creating natural overlap chains
- Load difference between reviewers is at most `ceil(N*3/R) - floor(N*3/R)` files (typically 0-2)

## N=1 Special Case

R=3, all reviewers see the same file. No allocation logic needed — equivalent to single-file behavior.
