# PRP: `-O / --CONVENTIONAL` flag for Conventional Commits messages

> Created: 2026-06-17
> Target file: `setver.sh` (single-file bashew script, ~1397 lines)
> Confidence score: **9/10** (see end)

---

## 1. Goal

Add a new boolean flag `-O | --CONVENTIONAL` to `setver`. When this flag is set during a
commit action (primarily `setver push`, but also `auto` / `skip`), instead of using the
auto-generated message or opening the `$EDITOR`, setver builds a
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/#summary) compliant
commit message **interactively**:

1. **Show the changed files first** (`git status --short`).
2. **Ask for the commit _type_** — picked from a numbered list (feat, fix, docs, …).
3. **(Optional) ask for a _scope_** — free text, may be left blank; the prompt shows preset
   examples (`commit version git changelog cli tests docs ci`) to encourage a consistent vocabulary.
4. **Ask for the _description_** (the short summary line) — same UX feel as `setver push`.

The resulting first line of the commit follows the spec:

```
<type>[(optional scope)][!]: <description>
```

Examples produced: `feat: add upstream branch detection`,
`fix(parser): handle leading zeros`, `docs: update README`.

Additionally, after a successful commit via `setver push` or `setver auto` (the non-`skipci`
modes), setver **suggests the matching next version bump** based on the chosen type, mapping
Conventional Commits → semver:

| commit type            | suggested next step      |
| ---------------------- | ------------------------ |
| `feat`                 | `setver new minor`       |
| `fix`                  | `setver new patch`       |
| any type with `!` (breaking) | `setver new major` |
| other (docs, chore, …) | `setver new patch`       |

e.g. after a `feat:` commit it prints:
`✔  Next step: setver new minor  (new feature)`. This is a printed suggestion only — it does
**not** auto-bump (the user stays in control, consistent with `setver`'s explicit `new` action).

## 2. Why

- `setver push` currently drops the user into a bare `git commit -a` editor with the
  auto-generated `ADD:/MOD:/DEL:` summary as a starting point. That message does **not**
  follow Conventional Commits, so downstream tooling (changelog generators, semantic-release,
  commitlint) can't parse it.
- Conventional Commits also map cleanly onto setver's existing semver bumping
  (`feat` → minor, `fix` → patch, `BREAKING CHANGE`/`!` → major), so this is a natural fit
  for a versioning tool.
- Keeping it behind an opt-in flag means existing behaviour is 100% unchanged unless the user
  asks for it.

## 3. Reference documentation (read these)

- Conventional Commits 1.0.0 summary: https://www.conventionalcommits.org/en/v1.0.0/#summary
- Spec full text (MUST/MAY rules, footers, `!` for breaking): https://www.conventionalcommits.org/en/v1.0.0/#specification
- Common type set (Angular convention, the de-facto standard list):
  https://github.com/angular/angular/blob/main/CONTRIBUTING.md#type
- `bash` `select` builtin (used for the numbered menu — POSIX bash, works on macOS):
  https://www.gnu.org/software/bash/manual/bash.html#index-select

### Conventional Commits rules that matter here

- Format of the summary line: `<type>[optional scope]: <description>` — a **type**, an
  **optional scope in parentheses**, a colon **and a space**, then the description. (Spec §1–§5)
- `feat` and `fix` are the only types the spec _defines_; other types (docs, chore, …) are
  allowed by convention. (Spec footnote — "types other than feat and fix MAY be used")
- A breaking change is signalled by a `!` immediately before the `:` (e.g. `feat!:` or
  `feat(api)!:`). (Spec §13) — we expose this as an optional prompt.
- Scope is a noun in parentheses, e.g. `fix(parser):`. (Spec §4)

## 4. Current codebase context (patterns to mirror)

All paths are in `setver.sh`.

### 4a. How flags are declared — `list_options()` (lines 9–22)

```bash
function list_options() {
  echo -n "
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|f|force|do not ask for confirmation
flag|r|root|do not check if in root folder of repo
flag|C|SKIP_COMPOSER|do not modify composer.json
flag|N|SKIP_NPM|do not modify package.json (for npm)
option|l|log_dir|folder for log files |$HOME/log/$script_prefix
option|t|tmp_dir|folder for temp files|/tmp/$script_prefix
option|p|prefix|prefix to use for git tags|v
param|1|action|action to perform: get/check/push/set/new/md/message/auto/autopatch/ap/skip/changelog/history
param|?|input|input text
"
}
```

> **GOTCHA:** `flag|X|NAME|desc` is auto-parsed by `init_options()` (line 1058) into a shell
> variable `NAME=0`. The single-letter short flag is **case-sensitive** and the upper-case
> short letters `C` and `N` are already taken. `O` (capital O, as requested) is free.
> The long name becomes the variable name verbatim, so `--CONVENTIONAL` → `$CONVENTIONAL`
> (value `0` or `1`). Mirror the existing `flag|C|SKIP_COMPOSER|...` style exactly.

### 4b. The commit entry point — `commit_and_push()` (lines 631–684)

```bash
function commit_and_push() {
  set +e
  trap - INT TERM EXIT
  local mode=${1:-}

  # ... .git-init check (638-647) ...
  # ... untracked-files staging check (649-660) ...

  local default_message=""
  default_message="$(def_commit_message)"
  debug "Commit message = [$default_message]"

  case "$mode" in
  skip-ci | skipci)
    success "Commit: $default_message [skip ci]"
    git commit -a -m "$default_message" -m "[skip ci]" && push_if_possible
    ;;
  auto | fast)
    success "Commit: $default_message"
    git commit -a -m "$default_message" && push_if_possible
    ;;
  *)
    # interactive commit  ← this is what `setver push` hits
    git commit -a && push_if_possible
    ;;
  esac
}
```

`setver push` → dispatch at line 107 → `commit_and_push` with **no** `mode`, hitting the `*)`
interactive branch.

### 4c. Auto-message generator — `def_commit_message()` (lines 606–629)

Uses `git status --short | awk ...` to produce `ADD:/MOD:/DEL:` summary. We reuse the **same
`git status --short`** call to show changed files, but format it for human reading.

### 4d. Interactive helpers already in the file (lines 864–885)

```bash
function confirm() {            # yes/no, auto-true when --force
  flag_set $force && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}

function ask() {                # ask "VARNAME" "question" "default"
  local ANSWER
  read -r -p "$2 ($3) > " ANSWER
  if [[ -z "$ANSWER" ]]; then eval "$1=\"$3\""; else eval "$1=\"$ANSWER\""; fi
}
```

### 4e. Output helpers (lines 787–798)

```bash
function out()     { ((quiet)) && true || printf '%b\n' "$*"; }
function debug()   { ((verbose)) && out "${col_ylw}# $* ${col_reset}" >&2 || true; }
function alert()   { out "${col_red}${char_alrt}${col_reset}: $*" >&2; }
function success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
function flag_set(){ [[ "$1" -gt 0 ]]; }
```

Use `out` / `success` / `alert` for all user-facing text. Use `flag_set $CONVENTIONAL` to test
the flag (matches `flag_set $force` usage at line 867).

### 4f. TIP/usage comments

Each action has a `#TIP:` comment above it (e.g. line 106). `list_options` (the action param,
line 21) lists valid actions. Conventional commit is a *modifier flag*, not a new action, so it
attaches to `push`; add a TIP near the `push` case explaining the flag.

## 5. Implementation blueprint

### Pseudocode

```
# 1. Declare flag in list_options():  flag|O|CONVENTIONAL|build a Conventional Commits message interactively

# 2. New helper: conventional_commit_message()
#    - prints the built "type(scope): description" line to STDOUT (so caller captures it)
#    - all prompts/menus go to STDERR (so they don't pollute the captured message)
conventional_commit_message():
    # show changed files (to stderr)
    print "Changed files:" >&2
    git status --short >&2

    # pick type via numbered menu (bash `select`, reads stdin, prompts on stderr)
    TYPES = (feat fix docs style refactor perf test build ci chore revert)
    show "type number?" menu  -> ctype     # default to nothing; loop until valid

    # optional scope (free text; print preset examples to guide a consistent vocabulary)
    print "examples: commit version git changelog cli tests docs ci" >&2
    read scope   (blank allowed)

    # optional breaking change — RAW read (not confirm()) so it always asks, even under --force
    read "Is this a BREAKING CHANGE? [y/N]"  -> bang = "!" if y, else ""

    # description (required, loop until non-empty; then light-normalize)
    repeat: read description ; until non-empty
    trim whitespace; strip one trailing "."; warn (don't block) if >50 chars

    # assemble
    header = ctype
    if scope nonempty: header += "(" scope ")"
    header += bang ": " description
    echo header        # STDOUT — the only thing on stdout

# 3. New helper: suggest_next_version_bump(header)
#    - parses the conventional header, prints "Next step: setver new <bump>"
suggest_next_version_bump(header):
    prefix = part of header before first ":"        # e.g. "feat(api)!"
    if prefix ends with "!":  bump=major ; reason="breaking change"
    else:
        ctype = prefix stripped from first "(" or "!"   # e.g. "feat"
        feat -> minor (new feature) ; fix -> patch (bug fix) ; * -> patch (<ctype> change)
    success "Next step: <prefix>new <bump>  (<reason>)"

# 4. In commit_and_push(), BEFORE the case "$mode": short-circuit when flag set
if flag_set $CONVENTIONAL:
    msg = conventional_commit_message()
    [[ -z msg ]] && die "empty conventional commit message"
    if mode is skipci:
        git commit -a -m msg -m "[skip ci]" && push_if_possible
    else:
        git commit -a -m msg && push_if_possible
        suggest_next_version_bump(msg)     # only for push/auto, NOT skipci
    return
```

> **KEY DESIGN GOTCHA — stdout vs stderr.** `conventional_commit_message` is called with
> command substitution `msg="$(conventional_commit_message)"`. Command substitution captures
> **stdout only**. Therefore every prompt, the changed-files listing, and the `select` menu must
> be written to **stderr** (`>&2`), and **only the final assembled header** goes to stdout via
> `echo`. This is the single most important detail to get right; mirror how `def_commit_message`
> echoes its result to stdout but note that here we also have interactive prompts that must NOT
> be captured.

> **GOTCHA — `select` and stdin.** Bash's `select` reads the chosen number from stdin and writes
> the menu to stderr automatically only if you redirect it; by default `select` prints the menu
> to **stderr** already and `PS3` to stderr — good. But the `$REPLY`/item read happens on stdin,
> so in tests we can feed it with `printf '1\n...' | setver -O push`. Keep the type array order
> **fixed** so the numbers are stable for tests (feat=1, fix=2, …).

> **GOTCHA — `--force` and the breaking-change prompt.** Do **NOT** use the existing `confirm`
> helper for the breaking-change question: `confirm` auto-returns true under `--force` (line 867),
> which would mark *every* forced commit as breaking. Use a **raw `read`** instead so the question
> is always asked, even with `-f`. (Decision: `-O` is inherently interactive; the breaking prompt
> always fires.) All other prompts (`select`, scope, description) also use raw `read`/`select`, so
> `--force` has no effect on them — they read from stdin as usual.

### Concrete code to add

**(A) Add to `list_options()`** (after the `flag|N|SKIP_NPM...` line, ~line 17):

```bash
flag|O|CONVENTIONAL|build a Conventional Commits message interactively
```

**(B) Add the helper** (place it next to `def_commit_message`, after line 629):

```bash
function conventional_commit_message() {
  # Build a Conventional Commits (https://www.conventionalcommits.org/en/v1.0.0/) header.
  # Prompts go to STDERR; only the final "type(scope): description" line goes to STDOUT,
  # because the caller captures stdout via $(...).
  local ctype="" scope="" descr="" bang="" header=""
  local -a types=(feat fix docs style refactor perf test build ci chore revert)

  # 1. show changed files
  out "${col_grn}Changed files:${col_reset}" >&2
  git status --short >&2

  # 2. pick the commit type from a numbered list
  out "Select the commit ${col_grn}type${col_reset}:" >&2
  local PS3="type # > "
  local opt
  select opt in "${types[@]}"; do
    if [[ -n "$opt" ]]; then
      ctype="$opt"
      break
    fi
    alert "invalid choice, try again" >&2
  done

  # 3. optional scope (free text; examples shown to guide a consistent vocabulary)
  out "scope = the area of the codebase touched (optional)." >&2
  out "  examples: ${col_grn}commit version git changelog cli tests docs ci${col_reset}" >&2
  read -r -p "scope (leave blank for none) > " scope >&2 || true
  scope="${scope// /}"   # no spaces allowed in scope

  # 4. optional breaking change marker
  #    Use a RAW read (not confirm()) so this ALWAYS asks, even under --force.
  #    confirm() auto-returns true under --force, which would wrongly mark every commit breaking.
  local is_breaking=""
  read -r -p "Is this a BREAKING CHANGE? [y/N] > " is_breaking >&2 || true
  [[ "$is_breaking" =~ ^[Yy] ]] && bang="!"

  # 5. description (required, then light-normalized per Conventional Commits style)
  while [[ -z "$descr" ]]; do
    read -r -p "short description > " descr >&2 || true
  done
  descr="${descr#"${descr%%[![:space:]]*}"}"   # trim leading whitespace
  descr="${descr%"${descr##*[![:space:]]}"}"   # trim trailing whitespace
  descr="${descr%.}"                            # strip a single trailing period
  if [[ ${#descr} -gt 50 ]]; then
    alert "description is ${#descr} chars (>50) — consider shortening (not blocking)" >&2
  fi

  # 6. assemble the header
  header="$ctype"
  [[ -n "$scope" ]] && header="$header($scope)"
  header="$header$bang: $descr"
  echo "$header"
}
```

> Note: `read -r -p "..." var >&2` — the `-p` prompt is always written to stderr by `read`, so
> the `>&2` on the variable is belt-and-suspenders; keep it for clarity. The captured value is
> assigned to the variable, not printed, so it never reaches stdout. Good.

**(C) Add the next-bump suggester** (place it right after `conventional_commit_message`):

```bash
function suggest_next_version_bump() {
  # $1 = conventional commit header, e.g. "feat(api)!: ..."  or  "fix: ..."
  # Maps Conventional Commits -> semver and prints the suggested `setver new <bump>` command.
  local header="$1" prefix="" ctype="" bump="" reason=""
  prefix="${header%%:*}"            # everything before the first ":" → "feat(api)!"
  if [[ "$prefix" == *"!" ]]; then
    bump="major"; reason="breaking change"
  else
    ctype="${prefix%%[(!]*}"        # strip scope/bang → "feat"
    case "$ctype" in
    feat) bump="minor"; reason="new feature" ;;
    fix)  bump="patch"; reason="bug fix" ;;
    *)    bump="patch"; reason="$ctype change" ;;
    esac
  fi
  success "Next step: ${col_grn}$script_prefix new $bump${col_reset}  ($reason)"
}
```

> **GOTCHA — parameter expansion, not regex.** `${header%%:*}` strips the longest `:`-suffix;
> `${prefix%%[(!]*}` strips from the first `(` or `!`. The `[(!]` is a glob bracket class (literal
> `(` and `!`), not a regex — no escaping needed. This avoids bash-version regex quirks and is
> shellcheck-clean. `$script_prefix` is the bashew var holding the command name (`setver`).

**(D) Hook into `commit_and_push()`** — insert right after `local mode=${1:-}` (line 635),
*before* the `.git` check is fine, but cleaner to insert *after* the untracked-files staging
block and *replace* the `default_message`/`case` section start. Recommended: insert just before
`local default_message=""` (line 662):

```bash
  if flag_set $CONVENTIONAL; then
    local conv_message=""
    conv_message="$(conventional_commit_message)"
    [[ -z "$conv_message" ]] && die "empty conventional commit message"
    case "$mode" in
    skip-ci | skipci)
      success "Commit: $conv_message [skip ci]"
      git commit -a -m "$conv_message" -m "[skip ci]" && push_if_possible
      ;;
    *)
      # push / auto / "" : commit, push, then suggest the matching version bump
      success "Commit: $conv_message"
      git commit -a -m "$conv_message" && push_if_possible
      suggest_next_version_bump "$conv_message"
      ;;
    esac
    return
  fi
```

> **Why only the `*)` branch suggests:** the `skipci` mode means "don't trigger CI / a release",
> so suggesting a version bump there would be contradictory. The suggestion fires for
> `setver -O push` (mode `""`) and `setver -O auto` (mode `auto`), exactly as requested.

**(E) Add a TIP** above the `push` case (line 106) so usage shows it:

```bash
    #TIP: use «$script_prefix -O push» to commit/push with an interactive Conventional Commits message
```

**(F) Documentation** — update `README.md` (the "Smart commit & push helpers" section, ~line 76)
and `CLAUDE.md` (Flags section) to mention `-O|--CONVENTIONAL` and the next-bump suggestion.

## 6. Task list (in order)

1. **Add flag declaration** to `list_options()` in `setver.sh` (`flag|O|CONVENTIONAL|...`).
2. **Add `conventional_commit_message()`** helper after `def_commit_message()` (~line 629).
3. **Add `suggest_next_version_bump()`** helper right after it.
4. **Hook the flag into `commit_and_push()`** with the short-circuit block before the existing
   `default_message`/`case` logic; call `suggest_next_version_bump` in the non-`skipci` branch.
5. **Add the `#TIP:`** comment above the `push` action case.
6. **Update docs**: `README.md` smart-commit section + `CLAUDE.md` Flags list.
7. **Add bats tests** in `tests/setver.bats` (see §7).
8. **Run validation gates** (§8) and fix until green.
9. **Manual smoke test**: `printf '1\n\nn\nadd thing\n' | ./setver.sh -O push` in a throwaway
   repo → verify `git log -1 --pretty=%s` == `feat: add thing` **and** that the output contains
   `Next step: setver new minor`.

## 7. Testing strategy

Existing tests live in `tests/setver.bats` and load `tests/test_helper.bash`
(`setup_test_repo` makes a temp git repo with **no remote**, so `push_if_possible` no-ops —
commits stay local and are assertable). Pattern to copy (existing style uses `run_setver` and
`git log` assertions).

> **Testability note:** because the type menu and prompts read from **stdin**, tests feed input
> via a pipe. `select` with input `1\n` selects the first item (`feat`). Sequence of stdin lines
> for the full flow: `<type#>`, `<scope-or-blank>`, `<breaking y/n>`, `<description>`.
> All four prompts are full-line `read`s (the breaking-change prompt is a raw `read`, **not**
> `confirm`), so feed each as its own newline-terminated line, e.g. `printf '1\n\nn\nadd new file\n'`.

Add these tests (do **not** use `run_setver` since we must pipe stdin; call the script directly):

```bash
##############################################################################
# Conventional Commits (-O / --CONVENTIONAL) Tests
##############################################################################

@test "setver -O push - builds 'feat:' message from type selection" {
  echo "change" > newfile.txt
  git add newfile.txt
  # stdin: type#=1 (feat), scope=blank, breaking=n, description
  printf '1\n\nn\nadd new file\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "feat: add new file" ]
}

@test "setver -O push - includes scope when provided" {
  echo "change" > a.txt
  git add a.txt
  # type#=2 (fix), scope=parser, breaking=n, description
  printf '2\nparser\nn\nhandle leading zeros\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "fix(parser): handle leading zeros" ]
}

@test "setver -O push - adds '!' for breaking change" {
  echo "change" > b.txt
  git add b.txt
  # type#=1 (feat), scope=blank, breaking=y, description
  printf '1\n\ny\nremove legacy api\n' | "$SETVER_SCRIPT" -r -O push
  run git log -1 --pretty=%s
  [ "$output" = "feat!: remove legacy api" ]
}

@test "setver -O skip - appends [skip ci] body" {
  echo "change" > c.txt
  git add c.txt
  printf '3\n\nn\nupdate readme\n' | "$SETVER_SCRIPT" -r -O skip
  run git log -1 --pretty=%B
  [[ "$output" =~ "docs: update readme" ]]
  [[ "$output" =~ "[skip ci]" ]]
}

@test "setver -O push - suggests 'new minor' after a feat commit" {
  echo "change" > d.txt
  git add d.txt
  # capture the command's own stdout to assert the suggestion line
  run bash -c "printf '1\n\nn\nadd thing\n' | '$SETVER_SCRIPT' -r -O push"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "new minor" ]]
}

@test "setver -O skip - does NOT suggest a version bump" {
  echo "change" > e.txt
  git add e.txt
  run bash -c "printf '2\n\nn\nfix bug\n' | '$SETVER_SCRIPT' -r -O skip"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Next step" ]]
}
```

> Use the `-r` flag (do-not-check-root) in tests because the temp repo's `.git` is fine but the
> script's root check (`check_requirements`, line 154) may complain otherwise; existing tests
> rely on `run_setver` which already handles this — check `tests/test_helper.bash` `run_setver`
> for the exact flags it passes and mirror them (it likely already adds `-r`/`-f`). If
> `run_setver` can pipe stdin, prefer it; otherwise call `$SETVER_SCRIPT` directly as above.

## 8. Validation gates (executable)

```bash
# 1. Static analysis — must pass clean (matches existing CI expectations)
shellcheck setver.sh

# 2. Syntax check
bash -n setver.sh

# 3. Flag is wired up and visible in usage
./setver.sh --help 2>&1 | grep -- '--CONVENTIONAL'

# 4. Full test suite
bats tests/setver.bats
# or
tests/run-tests.sh

# 5. End-to-end smoke test in a scratch repo
tmp=$(mktemp -d) && ( cd "$tmp" && git init -q && git config user.email t@t.t && \
  git config user.name t && echo x > f.txt && git add f.txt && \
  printf '1\n\nn\nadd f\n' | "$OLDPWD/setver.sh" -r -O push && \
  test "$(git log -1 --pretty=%s)" = "feat: add f" && echo "SMOKE OK" )
rm -rf "$tmp"
```

All five gates must succeed. Iterate until `shellcheck` is clean and `bats` is all-green.

## 9. Error handling & edge cases

- **Empty description** → `read` loop repeats until non-empty (cannot produce an invalid header).
- **Invalid type number** → `select` loops; `alert` shown, re-prompts.
- **Scope with spaces** → stripped (`${scope// /}`) since spec scope is a single noun.
- **Description style** → light-normalized: leading/trailing whitespace trimmed, one trailing
  period stripped, and a non-blocking warning if >50 chars. Never rejects valid input.
- **`--force` + `-O`** → the breaking-change prompt uses a raw `read`, so it **always asks** even
  with `-f`; `--force` does not auto-mark commits as breaking. Other prompts read from stdin as usual.
- **No remote** → `push_if_possible` already no-ops (line 716–717), so local-only repos work.
- **`-O` combined with `auto`/`ap`** → `-O` short-circuits before the auto path, so the
  interactive conventional flow wins. (Acceptable; `auto` means "don't prompt", `-O` means
  "prompt for a conventional message" — the explicit flag takes precedence. Document this.)
- **Next-step suggestion is advisory only** → `suggest_next_version_bump` only prints; it never
  runs `set_versions`, so a wrong type choice has no destructive effect. Not shown for `skipci`.
- **shellcheck**: use `# shellcheck disable=SC2154` if it flags `$CONVENTIONAL`/`$force` as
  possibly-unset (they're set by `init_options` via eval, same as `$force`, `$SKIP_COMPOSER`).
  Check whether existing flags already carry such disables and mirror.

## 10. Anti-patterns to avoid

- ❌ Printing prompts/menus to **stdout** — they'd be captured into the commit message. Always `>&2`.
- ❌ Adding `CONVENTIONAL` as a new **action** (param) — it's a **flag** modifier on `push`.
- ❌ Hard-coding colour escape codes — use the `col_grn`/`col_reset` vars and `out`/`success`.
- ❌ Re-implementing the git-init / untracked-staging logic — it already runs earlier in
  `commit_and_push`; the short-circuit is placed *after* those checks.
- ❌ Breaking the no-flag default path — everything must behave identically when `-O` is absent.

---

## Confidence score: 9.5/10

Reasoning: the codebase is a single, well-structured file with clear, mirror-able patterns for
flags (`flag|C|SKIP_COMPOSER`), interactive prompts (`confirm`/`ask`), output helpers, and a
single commit chokepoint (`commit_and_push`). The Conventional Commits spec is small and fully
referenced. All previously-open product decisions are now resolved (see below). The only residual
risk is the **stdout/stderr discipline** in command substitution and `select`/`read` stdin handling
in bats — both are explicitly called out with the exact technique to feed input, and the smoke-test
gate de-risks the cross-platform `read`/`select` behaviour.

### Resolved decisions (locked in)

- **Type list:** full Angular set of 11, fixed order — `feat fix docs style refactor perf test
  build ci chore revert` (menu numbers 1–11, stable for tests).
- **Scope:** free-text, optional, prompt shows preset examples (`commit version git changelog cli
  tests docs ci`).
- **Breaking-change prompt:** raw `read`, **always asks** even under `--force` (never auto-marked).
- **Next-step suggestion:** shown for `push`/`auto` only (not `skipci`); `feat`→minor, `fix`→patch,
  `!`→major, all other types→patch. Advisory only — never auto-bumps.
- **Description:** light normalization (trim whitespace, strip one trailing period, warn but don't
  block if >50 chars).
