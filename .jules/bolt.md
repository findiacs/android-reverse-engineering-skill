
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-17 - [Optimize multiple greps with single-pass caching]
**Learning:** Running multiple `grep` commands against a large directory tree causes significant I/O overhead. Also, when writing bash wrapper functions for `grep`, optional flags like `-i` must be explicitly handled (e.g., using `shift`), otherwise they might be incorrectly interpreted as positional arguments (the search pattern).
**Action:** Use a two-pass function execution model: a "collection" pass that builds an array of patterns without executing, followed by a single-pass `grep` with a combined regex to extract potentially matching lines into a temporary file. Then, run specific `grep` queries against this smaller cache file using a strictly constrained regex (e.g., `:[0-9]+:.*(pattern)`) to avoid false positives with filenames.
