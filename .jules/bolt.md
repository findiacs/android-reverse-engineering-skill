## 2024-05-24 - Avoid External Commands in Bash Loops
**Learning:** Using external commands like `$(basename "$var")` inside loops causes significant performance degradation due to subshell and fork/exec overhead. In performance testing, iterating over 3000 elements took ~7.6s with `basename`, but only ~0.06s with shell parameter expansion (`${var##*/}`).
**Action:** Always prefer built-in shell parameter expansions over external string manipulation commands (like `basename` or `dirname`) in performance-sensitive or looping contexts.
