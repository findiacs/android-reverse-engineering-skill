
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.
