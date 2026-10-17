#!/usr/bin/env bash
#
# Hackathon mode — every piece of mode logic, in one place (spec FR-017).
# Agent commands (/hack-kickoff, /speckit-hack-*) and native hooks only call this script.
#
#   scripts/hack.sh on        activate (once, on an unadopted template)
#   scripts/hack.sh status    show the mode; sync the active-spec pointer
#   scripts/hack.sh guard     permit or refuse a command (exit 2 = blocked)
#   scripts/hack.sh check     the enforcing check (pre-commit, verify.sh, CI)
#   scripts/hack.sh verify    the hackathon definition of done (called by scripts/verify.sh)
#   scripts/hack.sh issues    publish tasks.md work items as GitHub issues
#   scripts/hack.sh hooks     install local checks in event repositories
#   scripts/hack.sh graduate  leave hackathon mode for the full flow
#
# Contract: specs/001-hackathon-mode/contracts/hack-cli.md (exit codes 0 ok · 1 failed or
# refused · 2 blocked · 3 usage or environment). Bash 3.2 + python3 stdlib only.

set -uo pipefail

# The project root is where this script lives, not the caller's cwd: event-repository hooks
# (coordinating variant) call it from inside another repository.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && git rev-parse --show-toplevel 2>/dev/null) || {
  echo "hack: ERROR scripts/hack.sh must live inside a git repository" >&2
  exit 3
}
cd "$ROOT" || exit 3

MODE_FILE=.specify/mode.json
EXT_SRC=.specify/hack/extension
EXT_DIR=.specify/extensions/hack
HACK_CONSTITUTION=$EXT_DIR/templates/hack-constitution.md

info() { echo "hack: $*"; }
warn() {
  echo "hack: WARN $*"
  [[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "::warning::$*"
  return 0
}
err() {
  echo "hack: ERROR $*" >&2
  [[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "::error::$*" >&2
  return 0
}
die() {
  local code="$1"
  shift
  err "$*"
  exit "$code"
}

mode_active() { [[ -f "$MODE_FILE" ]]; }

# Past ends_at: warn, never change an exit code (spec FR-025).
warn_if_expired() {
  local ends
  ends=$(hpy expired "$MODE_FILE" 2>/dev/null) || return 0
  [[ -z "$ends" ]] || warn "hackathon ended $ends — graduate (/speckit-hack-graduate) or archive the repository"
  return 0
}

# --- python helpers (stdlib only; stdin stays free for `guard`) ----------------------------
read -r -d '' HACK_PY <<'PY'
import datetime, fnmatch, hashlib, json, os, re, sys

REQUIRED = ["mode", "variant", "event", "ends_at", "stack", "commands", "demo_check",
            "feature_directory", "spec_owner", "owners", "constitution_sha256", "activated_at"]
ALLOWED = set(REQUIRED) | {"runtime", "event_repos"}

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def is_dt(v):
    if not isinstance(v, str):
        return False
    try:
        d = datetime.datetime.fromisoformat(v.replace("Z", "+00:00"))
    except ValueError:
        return False
    return d.tzinfo is not None

def nonempty(v):
    return isinstance(v, str) and v != ""

def validate(m):
    e = []
    if not isinstance(m, dict):
        return ["mode record: expected a JSON object"]
    for k in REQUIRED:
        if k not in m:
            e.append(f"{k}: required")
    for k in m:
        if k not in ALLOWED:
            e.append(f"{k}: unknown key")
    if "mode" in m and m["mode"] != "hackathon":
        e.append('mode: must be "hackathon"')
    if "variant" in m and m["variant"] not in ("standard", "coordinating"):
        e.append('variant: must be "standard" or "coordinating"')
    for k in ("event", "stack", "spec_owner"):
        if k in m and not nonempty(m[k]):
            e.append(f"{k}: must be a non-empty string")
    for k in ("ends_at", "activated_at"):
        if k in m and not is_dt(m[k]):
            e.append(f"{k}: must be an ISO-8601 date-time with offset")
    if "runtime" in m and not (isinstance(m["runtime"], dict) and all(isinstance(v, str) for v in m["runtime"].values())):
        e.append("runtime: must map names to version strings")
    c = m.get("commands")
    if "commands" in m:
        if not isinstance(c, dict):
            e.append("commands: must be an object")
        else:
            for k in c:
                if k not in ("run", "build", "smoke"):
                    e.append(f"commands.{k}: unknown key")
            if not nonempty(c.get("run")):
                e.append("commands.run: must be a non-empty string")
            for k in ("build", "smoke"):
                if k not in c:
                    e.append(f"commands.{k}: required (string or null)")
                elif c[k] is not None and not isinstance(c[k], str):
                    e.append(f"commands.{k}: must be a string or null")
    if "demo_check" in m:
        if m["demo_check"] not in ("automated", "manual"):
            e.append('demo_check: must be "automated" or "manual"')
        elif isinstance(c, dict):
            if m["demo_check"] == "manual" and c.get("smoke") is not None:
                e.append("commands.smoke: must be null when demo_check is manual")
            if m["demo_check"] == "automated" and not isinstance(c.get("smoke"), str):
                e.append("commands.smoke: must be a string when demo_check is automated")
    if "feature_directory" in m and not (isinstance(m["feature_directory"], str) and re.fullmatch(r"specs/[0-9]{3}-[a-z0-9-]+", m["feature_directory"])):
        e.append("feature_directory: must match ^specs/[0-9]{3}-[a-z0-9-]+$")
    if "constitution_sha256" in m and not (isinstance(m["constitution_sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", m["constitution_sha256"])):
        e.append("constitution_sha256: must match ^[0-9a-f]{64}$")
    repos = m.get("event_repos")
    names = set()
    if "event_repos" in m:
        if not isinstance(repos, list):
            e.append("event_repos: must be an array")
            repos = []
        for i, r in enumerate(repos):
            if not isinstance(r, dict):
                e.append(f"event_repos[{i}]: must be an object")
                continue
            for k in ("name", "path", "url", "target_branch"):
                if k not in r:
                    e.append(f"event_repos[{i}].{k}: required")
            for k in r:
                if k not in ("name", "path", "url", "target_branch"):
                    e.append(f"event_repos[{i}].{k}: unknown key")
            if "name" in r:
                if not (isinstance(r["name"], str) and re.fullmatch(r"[a-z0-9-]+", r["name"])):
                    e.append(f"event_repos[{i}].name: must match ^[a-z0-9-]+$")
                names.add(r.get("name"))
            if "target_branch" in r and not nonempty(r["target_branch"]):
                e.append(f"event_repos[{i}].target_branch: must be a non-empty string")
    if m.get("variant") == "coordinating" and not repos:
        e.append("event_repos: variant coordinating requires at least 1 event repository")
    owners = m.get("owners")
    if "owners" in m:
        if not isinstance(owners, list) or not owners:
            e.append("owners: must be an array with at least 1 item")
            owners = []
        seen = {}
        for i, o in enumerate(owners):
            if not isinstance(o, dict):
                e.append(f"owners[{i}]: must be an object")
                continue
            for k in o:
                if k not in ("member", "paths"):
                    e.append(f"owners[{i}].{k}: unknown key")
            if not nonempty(o.get("member")):
                e.append(f"owners[{i}].member: must be a non-empty string")
            paths = o.get("paths")
            if not (isinstance(paths, list) and paths and all(nonempty(p) for p in paths)):
                e.append(f"owners[{i}].paths: must be a non-empty array of strings")
                continue
            for p in paths:
                if p in seen:
                    e.append(f"owners: a path pattern must not appear under two owners ({p}: {seen[p]}, {o.get('member')})")
                seen[p] = o.get("member")
                if m.get("variant") == "coordinating":
                    prefix = p.split(":", 1)[0] if ":" in p else None
                    if prefix not in names:
                        e.append(f"owners[{i}].paths: '{p}' must be prefixed by an event repository name ('<repo>:')")
    return e

def get(m, dotted):
    v = m
    for part in dotted.split("."):
        if isinstance(v, dict) and part in v:
            v = v[part]
        else:
            return ""
    if v is None:
        return ""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (dict, list)):
        return json.dumps(v)
    return str(v)

def slug(text):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:40].strip("-")

def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def lines(name):
    return [x for x in os.environ.get(name, "").splitlines() if x.strip()]

def build_mode():
    env = os.environ
    owners = []
    for spec in lines("HACK_OWNERS"):
        member, _, paths = spec.partition("=")
        owners.append({"member": member, "paths": [p for p in paths.split(",") if p]})
    runtime = {}
    for spec in lines("HACK_RUNTIME"):
        name, _, version = spec.partition("=")
        runtime[name] = version
    repos = []
    for spec in lines("HACK_EVENT_REPOS"):
        name, _, rest = spec.partition("=")
        parts = (rest.split(",") + ["", "", ""])[:3]
        repos.append({"name": name, "path": parts[0], "url": parts[1], "target_branch": parts[2]})
    smoke = None if env["HACK_SMOKE"] == "manual" else env["HACK_SMOKE"]
    m = {
        "mode": "hackathon",
        "variant": env.get("HACK_VARIANT", "standard"),
        "event": env["HACK_EVENT"],
        "ends_at": env["HACK_ENDS_AT"],
        "stack": env["HACK_STACK"],
    }
    if runtime:
        m["runtime"] = runtime
    m["commands"] = {
        "run": env["HACK_RUN"],
        "build": None if env["HACK_BUILD"] == "none" else env["HACK_BUILD"],
        "smoke": smoke,
    }
    m["demo_check"] = "manual" if smoke is None else "automated"
    m["feature_directory"] = "specs/001-" + slug(env["HACK_EVENT"])
    m["spec_owner"] = env["HACK_SPEC_OWNER"]
    m["owners"] = owners
    if repos:
        m["event_repos"] = repos
    m["constitution_sha256"] = env.get("HACK_CONSTITUTION_SHA", "0" * 64)
    m["activated_at"] = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
    return m

def adopt_agents(path, name, purpose, stack, run, test, lint, build):
    text = open(path, encoding="utf-8").read()
    out, skip_section = [], False
    for line in text.splitlines(keepends=True):
        if line.startswith("## 0. First run"):
            skip_section = True
            continue
        if skip_section:
            if line.startswith("## "):
                skip_section = False
            else:
                continue
        if line.startswith("> Replace the `<PROJECT>` placeholders") or line.startswith("> (§0 is temporary scaffolding"):
            continue
        if line.startswith("> Keep this file short. If it grows past ~120 lines, move detail into `docs/`"):
            line = "> Keep this file short. If it grows past ~120 lines, move detail into `docs/`.\n"
        if line.startswith("- **Name:**"):
            line = f"- **Name:** `{name}`\n"
        elif line.startswith("- **Purpose:**"):
            line = f"- **Purpose:** {purpose}\n"
        elif line.startswith("- **Stack:**"):
            line = f"- **Stack:** {stack}\n"
        elif line.startswith("- **Run:**"):
            line = f"- **Run:** `{run}` · **Test:** {test} · **Lint:** {lint} · **Build:** {build}\n"
        out.append(line)
    open(path, "w", encoding="utf-8").write("".join(out))

def strip_block(path, begin, end):
    src = open(path, encoding="utf-8").read().splitlines(keepends=True)
    out, inside, collapse = [], False, False
    for line in src:
        if begin in line:
            inside = True
            continue
        if inside:
            if end in line:
                inside, collapse = False, True
            continue
        if collapse and line.strip() == "" and (not out or out[-1].strip() == ""):
            collapse = False
            continue
        collapse = False
        out.append(line)
    text = "".join(out).rstrip("\n") + "\n"
    open(path, "w", encoding="utf-8").write(text)

def integrations():
    d = load(".specify/integration.json")
    default = d.get("default_integration") or d.get("integration")
    print(default)
    for k in d.get("installed_integrations", []):
        if k != default:
            print(k)

def unregistered(ext):
    reg = load(".specify/extensions/.registry").get("extensions", {}).get(ext, {}).get("registered_commands", {})
    inst = load(".specify/integration.json").get("installed_integrations", [])
    print(" ".join(k for k in inst if not reg.get(k)))

ALLOWED_SPEC_FILES = {"spec.md", "plan.md", "tasks.md", "demo.md", "debt.md"}

def prompt_cmd():
    raw = os.environ.get("HACK_PAYLOAD", "")
    try:
        data = json.loads(raw)
        text = data.get("prompt", "") if isinstance(data, dict) else ""
    except ValueError:
        text = raw
    first = (text or "").strip().split(None, 1)
    print(first[0] if first and first[0].startswith("/") else "")

def check_tree(mode_path, constitution):
    m = load(mode_path)
    feature = m["feature_directory"]
    errors = []
    if os.path.isdir("specs"):
        for name in sorted(os.listdir("specs")):
            if f"specs/{name}" != feature:
                errors.append(f"specs/{name}: only one spec per hackathon project, and it is {feature} — remove this, or fold it into the active spec with /speckit-hack-sprint")
    if os.path.isdir(feature):
        for dirpath, _, files in os.walk(feature):
            for f in files:
                rel = os.path.relpath(os.path.join(dirpath, f), feature)
                if rel not in ALLOWED_SPEC_FILES:
                    errors.append(f"{feature}/{rel}: not allowed in the hackathon spec (only spec.md, plan.md, tasks.md, demo.md, debt.md) — full-flow artifacts are disabled in hackathon mode")
    if os.path.isdir(".specify/bugs"):
        for dirpath, _, files in os.walk(".specify/bugs"):
            for f in files:
                errors.append(f"{os.path.join(dirpath, f)}: the bug lane (.specify/bugs) is disabled in hackathon mode — fix directly once the demo check reproduces it, otherwise add it to {feature}/debt.md")
    if not os.path.isfile(constitution) or sha256(constitution) != m["constitution_sha256"]:
        errors.append(f"{constitution}: the hackathon constitution changed — it is fixed in hackathon mode; restore it with git checkout")
    for x in errors:
        print(x)
    sys.exit(1 if errors else 0)

def owners_warn(mode_path, repo, files):
    m = load(mode_path)
    hits = {}
    for o in m.get("owners", []):
        pats = []
        for p in o.get("paths", []):
            if repo:
                if p.startswith(repo + ":"):
                    pats.append(p[len(repo) + 1:])
            elif m.get("variant") != "coordinating":
                pats.append(p)
        for f in files:
            if any(fnmatch.fnmatch(f, p) for p in pats):
                hits.setdefault(o["member"], []).append(f)
    if len(hits) > 1:
        for member, fs in hits.items():
            shown = ", ".join(fs[:5]) + (" …" if len(fs) > 5 else "")
            print(f"this change touches paths owned by {member}: {shown} — split work by owner")

WORK_ITEM = re.compile(r"^- \[[ xX]\] (H\d{3,}) \[@([^\]]+)\] \[slice: ([^\]]+)\] \[≤(\d+)m\] (.+?) — paths: (.+)$")

def work_items(tasks_path, mode_path):
    m = load(mode_path)
    owned = {o["member"]: o.get("paths", []) for o in m.get("owners", [])}
    errors, items = [], []
    for line in open(tasks_path, encoding="utf-8"):
        hit = WORK_ITEM.match(line.rstrip("\n"))
        if not hit:
            continue
        wid, member, slice_, box, desc, paths = hit.groups()
        globs = [p.strip() for p in paths.split(",") if p.strip()]
        if member not in owned:
            errors.append(f"{wid}: @{member} is not in the ownership map (owners in .specify/mode.json)")
            continue
        for g in globs:
            if not any(fnmatch.fnmatch(g, pat) for pat in owned[member]):
                errors.append(f"{wid}: {member} does not own {g} — split the work item by owner")
        title = desc if len(desc) <= 80 else desc[:79].rstrip() + "…"  # GitHub caps titles at 256
        items.append("\t".join([wid, member, slice_, box, desc, ", ".join(globs), title]))
    for x in errors:
        print(x, file=sys.stderr)
    if errors:
        sys.exit(1)
    for x in items:
        print(x)

def existing_ids(titles_json):
    found = set()
    for t in json.loads(titles_json or "[]"):
        found.update(re.findall(r"\bH\d{3,}\b", t.get("title", "")))
    print("\n".join(sorted(found)))

NOTICE_BEGIN, NOTICE_END = "<!-- hackathon-mode:begin -->", "<!-- hackathon-mode:end -->"

def add_notice(path, text):
    src = open(path, encoding="utf-8").read().splitlines(keepends=True)
    i = 0
    if src and src[0].strip() == "---":          # keep frontmatter first (.mdc)
        i = 1
        while i < len(src) and src[i].strip() != "---":
            i += 1
        i += 1
    while i < len(src) and not src[i].startswith("# "):
        i += 1
    i = i + 1 if i < len(src) else 0             # after the title, else at the top
    block = ["\n", NOTICE_BEGIN + "\n", text.rstrip("\n") + "\n", NOTICE_END + "\n"]
    open(path, "w", encoding="utf-8").write("".join(src[:i] + block + src[i:]))

def status_lines(m):
    out = [f"event: {m['event']}", f"ends at: {m['ends_at']}", f"variant: {m['variant']}"]
    rt = ", ".join(f"{k} {v}" for k, v in m.get("runtime", {}).items())
    out.append(f"stack: {m['stack']}" + (f" (runtimes: {rt})" if rt else ""))
    out.append(f"active spec: {m['feature_directory']}")
    out.append(f"spec owner: @{m['spec_owner']}")
    out.append("owners: " + "; ".join(f"@{o['member']} {', '.join(o['paths'])}" for o in m["owners"]))
    for r in m.get("event_repos", []):
        out.append(f"event repo {r['name']}: {r['path']} → submit to {r['target_branch']} ({r['url']})")
    out.append("allowed: /speckit-hack-sprint (spec owner), /speckit-hack-demo, /speckit-hack-status, /speckit-implement, /speckit-converge, /speckit-hack-graduate")
    out.append("blocked: /speckit-constitution, /speckit-specify, /speckit-clarify, /speckit-plan, /speckit-tasks, /speckit-analyze, /speckit-checklist, /speckit-bug-*, /kickoff")
    smoke = m["commands"]["smoke"] or "MANUAL demo checklist (demo.md)"
    build = m["commands"]["build"] or "n/a"
    out.append(f"done = scripts/verify.sh --full: check + demo check ({smoke}) + build ({build})")
    print("\n".join(out))

def sh_quote(cmd):
    return cmd.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$")

def set_verify(path, lint, test, build):
    text = open(path, encoding="utf-8").read()
    for var, val in (("LINT_CMD", lint), ("TEST_CMD", test), ("BUILD_CMD", build)):
        text = re.sub(rf'^{var}="\$\{{{var}:-.*\}}"$', f'{var}="${{{var}:-{sh_quote(val)}}}"', text, count=1, flags=re.M)
    open(path, "w", encoding="utf-8").write(text)

def graduate_agents(path, lint, test, build):
    out = []
    for line in open(path, encoding="utf-8").read().splitlines(keepends=True):
        if line.startswith("- **Purpose:**"):
            line = line.replace(" (hackathon mode)", "")
        elif line.startswith("- **Run:**"):
            run = line.split("·")[0].rstrip()
            b = f"`{build}`" if build else "n/a"
            line = f"{run} · **Test:** `{test}` · **Lint:** `{lint}` · **Build:** {b}\n"
        out.append(line)
    open(path, "w", encoding="utf-8").write("".join(out))

DEBT = re.compile(r"^- (D\d{3,}) \| (.+?) \| where: (.+?) \| why: (.+?) \| repay: (.+)$")

def debt_to_tasks(feature):
    debt, tasks = os.path.join(feature, "debt.md"), os.path.join(feature, "tasks.md")
    if not os.path.isfile(debt):
        print(0)
        return
    rows = []
    for line in open(debt, encoding="utf-8"):
        hit = DEBT.match(line.rstrip("\n"))
        if hit:
            did, what, where, _why, repay = hit.groups()
            rows.append(f"- [ ] T9{did[1:]} {what} — where: {where} — repay: {repay}\n")
    if rows:
        existing = open(tasks, encoding="utf-8").read() if os.path.isfile(tasks) else ""
        head = "" if existing.endswith("\n\n") or not existing else ("\n" if existing.endswith("\n") else "\n\n")
        with open(tasks, "a", encoding="utf-8") as f:
            f.write(head + "## Inherited debt\n\n<!-- From hackathon mode (debt.md). /speckit-converge picks these up. -->\n\n" + "".join(rows))
    os.remove(debt)
    print(len(rows))

def precommit_rev(repo_url_part):
    lines = open(".pre-commit-config.yaml", encoding="utf-8").read().splitlines()
    for i, line in enumerate(lines):
        if repo_url_part in line:
            for nxt in lines[i + 1:i + 4]:
                hit = re.match(r"\s*rev:\s*(\S+)", nxt)
                if hit:
                    return hit.group(1)
    raise SystemExit(f"no rev for {repo_url_part} in .pre-commit-config.yaml")

def event_config(root, name, target, out):
    q = json.dumps
    text = f"""# Generated by scripts/hack.sh hooks for event repository '{name}' — machine-local, not committed.
repos:
  - repo: https://github.com/betterleaks/betterleaks
    rev: {precommit_rev("betterleaks/betterleaks")}
    hooks:
      - id: betterleaks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: {precommit_rev("pre-commit/pre-commit-hooks")}
    hooks:
      - id: detect-private-key
  - repo: local
    hooks:
      - id: hack-event-check
        name: {q("hackathon mode check (" + name + ", local-only)")}
        entry: {q(root + "/scripts/hack.sh check --event-repo " + name + " --changed")}
        language: system
        pass_filenames: true
        always_run: true
        verbose: true
        stages: [pre-commit]
      - id: hack-push-note
        name: {q("hackathon mode: target branch")}
        entry: {q(root + "/scripts/hack.sh check --event-repo " + name + " --push-note")}
        language: system
        pass_filenames: false
        always_run: true
        verbose: true
        stages: [pre-push]
"""
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w", encoding="utf-8").write(text)

def event_repos(mode_path):
    for r in load(mode_path).get("event_repos", []):
        print("\t".join([r["name"], r["path"], r["target_branch"]]))

def expired(mode_path):
    ends = load(mode_path)["ends_at"]
    end = datetime.datetime.fromisoformat(ends.replace("Z", "+00:00"))
    if datetime.datetime.now(datetime.timezone.utc) > end:
        print(ends)

op, args = sys.argv[1], sys.argv[2:]
if op == "expired":
    expired(args[0])
elif op == "event-config":
    event_config(*args)
elif op == "event-repos":
    event_repos(args[0])
elif op == "set-verify":
    set_verify(*args)
elif op == "graduate-agents":
    graduate_agents(*args)
elif op == "debt-to-tasks":
    debt_to_tasks(args[0])
elif op == "add-notice":
    add_notice(args[0], os.environ["HACK_NOTICE"])
elif op == "status-lines":
    status_lines(load(args[0]))
elif op == "work-items":
    work_items(*args)
elif op == "existing-ids":
    existing_ids(os.environ.get("HACK_TITLES", "[]"))
elif op == "prompt-cmd":
    prompt_cmd()
elif op == "check-tree":
    check_tree(*args)
elif op == "owners":
    owners_warn(args[0], args[1], args[2:])
elif op == "build-mode":
    m = build_mode()
    errors = validate(m)
    for x in errors:
        print(x, file=sys.stderr)
    if errors:
        sys.exit(1)
    open(args[0], "w", encoding="utf-8").write(json.dumps(m, indent=2, ensure_ascii=False) + "\n")
elif op == "adopt-agents":
    adopt_agents(*args)
elif op == "strip-block":
    strip_block(*args)
elif op == "integrations":
    integrations()
elif op == "unregistered":
    unregistered(args[0])
elif op == "validate":
    try:
        errors = validate(load(args[0]))
    except (OSError, ValueError) as exc:
        errors = [f"mode record: unreadable ({exc})"]
    for x in errors:
        print(x)
    sys.exit(1 if errors else 0)
elif op == "get":
    print(get(load(args[0]), args[1]))
elif op == "slug":
    print(slug(args[0]))
elif op == "sha256":
    print(sha256(args[0]))
else:
    print(f"unknown helper op: {op}", file=sys.stderr)
    sys.exit(3)
PY

hpy() { python3 -I -c "$HACK_PY" "$@"; }
mode_get() { hpy get "$MODE_FILE" "$1"; }

# mode_validate — exit 3 naming each invalid field (contracts/mode-record.schema.json).
mode_validate() {
  local out
  if ! out=$(hpy validate "$MODE_FILE"); then
    while IFS= read -r line; do err "$MODE_FILE: $line"; done <<<"$out"
    exit 3
  fi
}

# --- on ----------------------------------------------------------------------------------
PLACEHOLDERS='<PROJECT_NAME>\|<ONE_SENTENCE>\|<LANGUAGES / FRAMEWORKS>\|<COMMAND>'

tmpfile() { mktemp "${TMPDIR:-/tmp}/hack.XXXXXX"; }

# Install the extension for every installed integration (research "Spike results"):
# `extension add` registers the default integration only, `integration use <key>` registers
# the others, and its side effects on files that were already tracked are undone.
install_extension() {
  local out idx snap default key others path
  out=$(specify extension add --dev "$EXT_SRC" 2>&1) || { printf '%s\n' "$out" >&2; return 1; }
  idx="$(mktemp -d "${TMPDIR:-/tmp}/hack-idx.XXXXXX")/index"
  GIT_INDEX_FILE="$idx" git add -A && snap=$(GIT_INDEX_FILE="$idx" git write-tree) || return 1
  rm -rf "$(dirname "$idx")"
  default=$(hpy integrations | head -n 1)
  others=$(hpy integrations | tail -n +2)
  for key in $others "$default"; do
    out=$(specify integration use "$key" 2>&1) || { printf '%s\n' "$out" >&2; return 1; }
  done
  git diff --name-only "$snap" | while IFS= read -r path; do
    case "$path" in
      .specify/extensions/.registry | .specify/integrations/*.manifest.json | .specify/integration.json) ;;
      *) git restore --source="$snap" --worktree -- "$path" ;;
    esac
  done
  local missing
  missing=$(hpy unregistered hack)
  [[ -z "$missing" ]] || { err "hack commands not registered for: $missing"; return 1; }
}

# Require the ci workflow's checks before merging (FR-022). Adds the contexts to existing
# branch protection when there is one, so other protection settings are preserved.
require_checks() {
  local repo branch
  if ! command -v gh >/dev/null 2>&1; then
    warn "gh not found — require the 'secrets' and 'verify' checks on the default branch by hand (Settings → Branches)"
    return 0
  fi
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
    && branch=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null) || {
    warn "could not resolve the GitHub repository — require the 'secrets' and 'verify' checks by hand"
    return 0
  }
  if gh api -X POST "repos/$repo/branches/$branch/protection/required_status_checks/contexts" \
    -f 'contexts[]=secrets' -f 'contexts[]=verify' >/dev/null 2>&1 \
    || gh api -X PUT "repos/$repo/branches/$branch/protection" --input - >/dev/null 2>&1 <<'JSON'
{"required_status_checks": {"strict": false, "contexts": ["secrets", "verify"]},
 "enforce_admins": false, "required_pull_request_reviews": null, "restrictions": null}
JSON
  then
    info "required checks 'secrets' and 'verify' on $repo:$branch"
  else
    warn "GitHub refused the branch-protection change — require 'secrets' and 'verify' on $branch by hand"
  fi
}

# Both on and graduate require a clean tree up front, so undoing = discarding their changes.
rollback() { # <subcommand> <step>
  err "$1: step '$2' failed — rolled back every change"
  git checkout -q -- . && git clean -fdq
  exit 1
}
on_rollback() { rollback on "$1"; }

cmd_on() {
  local event="" ends_at="" stack="" run="" build="" smoke="" spec_owner="" variant="standard"
  local owners="" runtime="" repos="" require_check=0 nl=$'\n'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --require-check) require_check=1; shift; continue ;;
      --event | --ends-at | --stack | --run | --build | --smoke | --spec-owner | --owner | --runtime | --variant | --event-repo)
        [[ $# -ge 2 ]] || die 3 "on: $1 needs a value" ;;
      *) die 3 "on: unknown argument '$1' (see contracts/hack-cli.md)" ;;
    esac
    case "$1" in
      --event) event=$2 ;;
      --ends-at) ends_at=$2 ;;
      --stack) stack=$2 ;;
      --run) run=$2 ;;
      --build) build=$2 ;;
      --smoke) smoke=$2 ;;
      --spec-owner) spec_owner=$2 ;;
      --variant) variant=$2 ;;
      --owner) owners="${owners:+$owners$nl}$2" ;;
      --runtime) runtime="${runtime:+$runtime$nl}$2" ;;
      --event-repo) repos="${repos:+$repos$nl}$2" ;;
    esac
    shift 2
  done
  local flag val missing=""
  for flag in event ends-at stack run build smoke spec-owner owner; do
    case "$flag" in
      event) val=$event ;; ends-at) val=$ends_at ;; stack) val=$stack ;; run) val=$run ;;
      build) val=$build ;; smoke) val=$smoke ;; spec-owner) val=$spec_owner ;; owner) val=$owners ;;
    esac
    [[ -n "$val" ]] || missing="$missing --$flag"
  done
  [[ -z "$missing" ]] || die 3 "on: missing required$missing (build: a command or 'none'; smoke: a command or 'manual')"

  mode_active && die 1 "hackathon mode is already active — a project's mode is chosen once; the only exit is /speckit-hack-graduate"
  [[ "$(grep -c "$PLACEHOLDERS" AGENTS.md)" != 0 ]] \
    || die 1 "AGENTS.md §1 is already adopted (full-mode or graduated project) — a project's mode is chosen once; hackathon mode needs a fresh template clone"

  local draft errors
  draft=$(tmpfile)
  if ! errors=$(HACK_EVENT=$event HACK_ENDS_AT=$ends_at HACK_STACK=$stack HACK_RUN=$run HACK_BUILD=$build \
    HACK_SMOKE=$smoke HACK_SPEC_OWNER=$spec_owner HACK_VARIANT=$variant HACK_OWNERS=$owners \
    HACK_RUNTIME=$runtime HACK_EVENT_REPOS=$repos hpy build-mode "$draft" 2>&1); then
    rm -f "$draft"
    while IFS= read -r line; do err "on: $line"; done <<<"$errors"
    exit 3
  fi
  [[ -z "$(git status --porcelain)" ]] || { rm -f "$draft"; die 1 "on: commit or stash your changes first — activation must be able to roll back cleanly"; }
  command -v specify >/dev/null 2>&1 || { rm -f "$draft"; die 3 "on: specify not found — run ./scripts/setup.sh"; }

  local slug feature
  slug=$(hpy slug "$event")
  feature=$(hpy get "$draft" feature_directory)

  # 1. template-owned specs/ and template-only CI (research R9, R16)
  rm -rf specs || on_rollback "remove template specs"
  hpy strip-block .github/workflows/ci.yml "# template-only:begin" "# template-only:end" || on_rollback "remove template-only CI"
  # 2. AGENTS.md §1, minus §0 (as /kickoff Step 2)
  hpy adopt-agents AGENTS.md "$slug" "Hackathon proof of concept for $event (hackathon mode)." "$stack" "$run" \
    "\`./scripts/verify.sh\` (hackathon mode: check + demo check)" "n/a (hackathon mode)" \
    "$([[ "$build" == none ]] && echo "n/a" || echo "\`$build\`")" || on_rollback "write AGENTS.md §1"
  # 3. the extension, for every installed integration
  install_extension || on_rollback "install the hack extension"
  # 4. the mode record
  HACK_CONSTITUTION_SHA=$(hpy sha256 "$HACK_CONSTITUTION") HACK_EVENT=$event HACK_ENDS_AT=$ends_at HACK_STACK=$stack \
    HACK_RUN=$run HACK_BUILD=$build HACK_SMOKE=$smoke HACK_SPEC_OWNER=$spec_owner HACK_VARIANT=$variant \
    HACK_OWNERS=$owners HACK_RUNTIME=$runtime HACK_EVENT_REPOS=$repos hpy build-mode "$MODE_FILE" \
    || on_rollback "write $MODE_FILE"
  rm -f "$draft"
  on_effects_after_record || on_rollback "post-activation effects"
  [[ "$require_check" == 1 ]] && require_checks

  info "hackathon mode active — event '$event', active spec $feature"
  info "next: /speckit-hack-sprint (spec owner: $spec_owner)"
  [[ "$variant" == coordinating ]] && info "each teammate, once per machine: scripts/hack.sh hooks"
  info "commit the result: git add -A && git commit -m \"chore: adopt template in hackathon mode\""
  return 0
}

# 6. the commit-time check (research R5)
add_precommit_block() {
  cat >>.pre-commit-config.yaml <<'YAML'
# hackathon-mode:begin — added by scripts/hack.sh on, removed by graduate
  - repo: local
    hooks:
      - id: hack-check
        name: hackathon mode check
        entry: scripts/hack.sh check --changed
        language: system
        pass_filenames: true
        always_run: true
# hackathon-mode:end
YAML
  if command -v pre-commit >/dev/null 2>&1 && [[ -f .git/hooks/pre-commit ]]; then
    pre-commit install >/dev/null 2>&1 || warn "re-run 'pre-commit install' to pick up the hack-check hook"
  fi
}

# 5. notices in every agent instruction file (FR-020)
NOTICE_FILES="AGENTS.md .github/copilot-instructions.md .cursor/rules/sdd-workflow.mdc .clinerules/00-agents.md"
notice_text() {
  local feature event
  feature=$(mode_get feature_directory)
  event=$(mode_get event)
  printf '%s\n' "> **HACKATHON MODE — ${event}.** Active spec: \`${feature}\`. Run \`scripts/hack.sh status\` first"
  printf '%s\n' "> (also before \`/speckit-implement\`: it syncs the active-spec pointer)."
  printf '%s\n' "> Done = \`scripts/verify.sh --full\` (check + demo check + build)."
  printf '%s\n' "> Allowed: \`/speckit-hack-sprint\` (spec owner), \`/speckit-hack-status\`, \`/speckit-implement\`, \`/speckit-converge\`, \`/speckit-hack-demo\`, \`/speckit-hack-graduate\`."
  printf '%s\n' "> Full-flow and bug-lane commands are disabled; do not create other specs. Log shortcuts in \`${feature}/debt.md\` as"
  printf '%s\n' "> \`- D<NNN> | <shortcut> | where: <path> | why: <reason> | repay: <what full mode needs>\`."
  if [[ "$(mode_get variant)" == coordinating ]]; then
    printf '%s\n' "> Code lives in the event repositories; enforcement there is local-only and can be"
    printf '%s\n' "> bypassed — run \`scripts/hack.sh hooks\` once per machine."
  fi
}
add_notices() {
  local f text
  text=$(notice_text)
  for f in $NOTICE_FILES; do
    [[ -f "$f" ]] || continue
    HACK_NOTICE=$text hpy add-notice "$f" || return 1
  done
}

# Effects that need the mode record, in contract order (contracts/hack-cli.md `on`).
on_effects_after_record() {
  add_notices && add_precommit_block
}

# --- status ------------------------------------------------------------------------------
# Rewrite Spec Kit's per-checkout pointer (gitignored) from the committed mode record (R9).
sync_feature_pointer() {
  printf '{\n  "feature_directory": "%s"\n}\n' "$(mode_get feature_directory)" >.specify/feature.json
}

cmd_status() {
  if ! mode_active; then
    info "full mode — this project follows the full Spec-Driven flow (AGENTS.md §2)"
    return 0
  fi
  mode_validate
  sync_feature_pointer
  echo "HACKATHON MODE"
  hpy status-lines "$MODE_FILE"
  warn_if_expired
  if [[ "$(mode_get variant)" == coordinating ]]; then
    warn "enforcement on event repositories is local-only and can be bypassed"
  fi
}

# --- guard -------------------------------------------------------------------------------
# Spec Kit ids blocked in hackathon mode, each with its redirect (spec FR-016, research R4).
redirect_for() {
  case "$1" in
    speckit.specify | speckit.plan | speckit.tasks) echo "use /speckit-hack-sprint (one pass: spec, plan, tasks, issues)" ;;
    speckit.clarify) echo "record an assumption in the spec's Assumptions section instead" ;;
    speckit.constitution) echo "the hackathon constitution is fixed until graduation" ;;
    speckit.analyze | speckit.checklist) echo "skipped in hackathon mode — the demo check is the definition of done" ;;
    speckit.bug.assess | speckit.bug.fix | speckit.bug.test) echo "fix directly once the demo check reproduces it; otherwise add it to debt.md" ;;
    kickoff) echo "a project's mode is chosen once; graduate is the only exit (/speckit-hack-graduate)" ;;
    *) return 1 ;;
  esac
}

# speckit.x.y | /speckit-x-y | speckit-x-y → speckit.x.y ; /kickoff → kickoff
normalize_id() {
  local id="${1#/}"
  case "$id" in
    speckit-*) echo "${id//-/.}" ;;
    *) echo "$id" ;;
  esac
}

# Read stdin without ever blocking: an open-but-silent pipe counts as empty.
read_stdin_nowait() {
  python3 -I -c 'import select, sys
r, _, _ = select.select([sys.stdin], [], [], 0.5)
sys.stdout.write(sys.stdin.read(1048576) if r else "")'
}

cmd_guard() {
  mode_active || return 0
  local id payload first redirect
  if [[ $# -gt 0 ]]; then
    id=$(normalize_id "$1")
  elif [[ ! -t 0 ]] && payload=$(read_stdin_nowait) && [[ -n "$payload" ]]; then
    first=$(HACK_PAYLOAD=$payload hpy prompt-cmd)
    [[ -n "$first" ]] || return 0
    id=$(normalize_id "$first")
  else
    # No argument and no input: a lifecycle hook, and those exist only on blocked commands.
    err "this command is disabled in hackathon mode — run scripts/hack.sh status to see what is allowed"
    exit 2
  fi
  redirect=$(redirect_for "$id") || return 0
  err "/${id//./-} is disabled in hackathon mode — $redirect"
  exit 2
}

# --- check -------------------------------------------------------------------------------
cmd_check() {
  local event_repo="" push_note=0 files=() out line
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --event-repo) [[ $# -ge 2 ]] || die 3 "check: --event-repo needs a name"; event_repo=$2; shift 2 ;;
      --push-note) push_note=1; shift ;;
      --changed) shift; files=("$@"); break ;;
      *) die 3 "check: unknown argument '$1'" ;;
    esac
  done
  mode_active || return 0
  mode_validate
  warn_if_expired
  if [[ "$push_note" == 1 ]]; then
    local target
    target=$(hpy event-repos "$MODE_FILE" | awk -F'\t' -v n="$event_repo" '$1 == n {print $3}')
    [[ -n "$target" ]] || die 3 "check: '$event_repo' is not an event repository in $MODE_FILE"
    info "target branch: $target (event repository $event_repo) — open pull requests against it, not the upstream default"
    warn "local-only check — nothing enforces this on the organizers' side"
    return 0
  fi
  local rc=0
  if [[ -n "$event_repo" ]]; then
    check_event_repo "$event_repo" "${files[@]+"${files[@]}"}" || rc=1
  else
    if ! out=$(hpy check-tree "$MODE_FILE" "$HACK_CONSTITUTION"); then
      while IFS= read -r line; do err "$line"; done <<<"$out"
      rc=1
    fi
  fi
  if [[ ${#files[@]} -gt 0 ]]; then
    out=$(hpy owners "$MODE_FILE" "$event_repo" "${files[@]}")
    [[ -z "$out" ]] || while IFS= read -r line; do warn "$line"; done <<<"$out"
  fi
  return "$rc"
}

# Event-repository mode (coordinating variant, FR-032/FR-033): Spec Kit artifacts belong in
# the coordinating project, never in an event repository.
check_event_repo() {
  local name="$1" f rc=0
  shift
  hpy event-repos "$MODE_FILE" | cut -f1 | grep -qx "$name" || die 3 "check: '$name' is not an event repository in $MODE_FILE"
  for f in "$@"; do
    case "$f" in
      specs/* | .specify/*)
        err "$f: Spec Kit artifacts belong in the coordinating project, not in event repository '$name'"
        rc=1
        ;;
    esac
  done
  warn "local-only check — nothing enforces this on the organizers' side"
  return "$rc"
}

# --- issues ------------------------------------------------------------------------------
cmd_issues() {
  local dry=0
  [[ "${1:-}" == "--dry-run" ]] && dry=1
  mode_active || die 1 "issues: not in hackathon mode"
  command -v gh >/dev/null 2>&1 || die 3 "issues: gh not found — install the GitHub CLI and run gh auth login"
  local feature tasks items titles existing
  feature=$(mode_get feature_directory)
  tasks="$feature/tasks.md"
  [[ -f "$tasks" ]] || die 1 "issues: $tasks not found — run /speckit-hack-sprint first"
  items=$(hpy work-items "$tasks" "$MODE_FILE" 2>&1) || {
    while IFS= read -r line; do err "issues: $line"; done <<<"$items"
    exit 1
  }
  titles=$(gh issue list --state all --json title --limit 1000 2>/dev/null) || die 1 "issues: gh could not list issues — check gh auth status"
  existing=$(HACK_TITLES=$titles hpy existing-ids)
  local id member slice box desc paths title body created=0 skipped=0
  while IFS=$'\t' read -r id member slice box desc paths title; do
    [[ -n "$id" ]] || continue
    if grep -qx "$id" <<<"$existing"; then skipped=$((skipped + 1)); continue; fi
    body="$desc"$'\n\n'"Slice: $slice"$'\n'"Time box: ≤${box} min"$'\n'"Paths: $paths"$'\n\n'"From $tasks (hackathon mode)."
    if [[ "$dry" == 1 ]]; then
      echo "would run: gh issue create --title \"$id $title\" --assignee $member"
    else
      gh issue create --title "$id $title" --assignee "$member" --body "$body" || die 1 "issues: gh issue create failed for $id"
    fi
    created=$((created + 1))
  done <<<"$items"
  info "issues: $created $([[ "$dry" == 1 ]] && echo "to create" || echo "created"), $skipped already published"
}

# --- hooks -------------------------------------------------------------------------------
cmd_hooks() {
  mode_active || die 1 "hooks: not in hackathon mode"
  if [[ "$(mode_get variant)" != coordinating ]]; then
    info "hooks: not needed — the standard variant's checks run from .pre-commit-config.yaml"
    return 0
  fi
  command -v pre-commit >/dev/null 2>&1 || die 3 "hooks: pre-commit not found — uv tool install pre-commit"
  local name path target dir cfg out rc=0
  while IFS=$'\t' read -r name path target; do
    [[ -n "$name" ]] || continue
    if ! dir=$(cd "$path" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null); then
      warn "hooks: event repository '$name' not found at $path — clone it there, then re-run scripts/hack.sh hooks"
      rc=1
      continue
    fi
    cfg="$ROOT/.specify/hack/local/event-$name-pre-commit.yaml"
    hpy event-config "$ROOT" "$name" "$target" "$cfg" || die 1 "hooks: could not write $cfg"
    if ! out=$(cd "$dir" && pre-commit install -c "$cfg" -t pre-commit -t pre-push 2>&1); then
      printf '%s\n' "$out" >&2
      err "hooks: pre-commit install failed in $dir"
      rc=1
      continue
    fi
    grep -qi "migration mode" <<<"$out" && warn "hooks: $name already had git hooks; pre-commit runs them in migration mode"
    info "hooks: $name ($dir) — secrets + hackathon check on commit, target branch '$target' shown on push"
  done < <(hpy event-repos "$MODE_FILE")
  warn "enforcement on event repositories is local-only and can be bypassed"
  return "$rc"
}

# --- graduate ----------------------------------------------------------------------------
default_branch() {
  local b
  b=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null) && echo "${b#origin/}" || echo main
}

cmd_graduate() {
  local lint="" test="" build="" code_repo=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lint | --test | --build | --code-repo) [[ $# -ge 2 ]] || die 3 "graduate: $1 needs a value" ;;
      *) die 3 "graduate: unknown argument '$1' (see contracts/hack-cli.md)" ;;
    esac
    case "$1" in
      --lint) lint=$2 ;; --test) test=$2 ;; --build) build=$2 ;; --code-repo) code_repo=$2 ;;
    esac
    shift 2
  done
  mode_active || die 1 "graduate: not in hackathon mode"
  [[ -n "$lint" && -n "$test" ]] || die 3 "graduate: --lint and --test are required (the real full-mode commands)"
  mode_validate
  local current def
  current=$(git rev-parse --abbrev-ref HEAD)
  def=$(default_branch)
  [[ "$current" == "$def" ]] || die 1 "graduate: run it on the default branch ($def), not '$current' — merge or close open work first"
  if [[ "$(mode_get variant)" == coordinating && -z "$code_repo" ]]; then
    die 1 "graduate: the code lives in event repositories — pass --code-repo <path to a repository the team owns>; if the team owns none, keep the proof of concept as is"
  fi
  [[ -z "$(git status --porcelain)" ]] || die 1 "graduate: commit or stash your changes first — graduation must be able to roll back cleanly"
  command -v specify >/dev/null 2>&1 || die 3 "graduate: specify not found — run ./scripts/setup.sh"

  local feature open_branches debt_count f
  feature=$(mode_get feature_directory)
  [[ -n "$build" ]] || build=$(mode_get commands.build)
  open_branches=$(git branch -a --no-merged 2>/dev/null | sed 's/^[* ]*//')

  # 1. full verification (as /kickoff Step 3) and AGENTS.md §1
  hpy set-verify scripts/verify.sh "$lint" "$test" "$build" || rollback graduate "set verify commands"
  hpy graduate-agents AGENTS.md "$lint" "$test" "$build" || rollback graduate "update AGENTS.md §1"
  # 2. debt becomes tasks
  debt_count=$(hpy debt-to-tasks "$feature") || rollback graduate "move debt to tasks"
  # 3. the extension (commands, hooks, native events)
  specify extension remove hack --force >/dev/null 2>&1 || rollback graduate "remove the hack extension"
  rm -rf .specify/extensions/.backup/hack
  # 4. sentinel blocks
  for f in $NOTICE_FILES; do
    [[ -f "$f" ]] && { hpy strip-block "$f" "<!-- hackathon-mode:begin -->" "<!-- hackathon-mode:end -->" || rollback graduate "remove notices"; }
  done
  for f in .pre-commit-config.yaml .github/workflows/ci.yml scripts/verify.sh; do
    hpy strip-block "$f" "# hackathon-mode:begin" "# hackathon-mode:end" || rollback graduate "remove hackathon blocks"
  done
  hpy strip-block AGENTS.md "<!-- template-only:begin -->" "<!-- template-only:end -->" || rollback graduate "remove template-only lines"
  # 5. the mode record and the hackathon tooling (research R16)
  rm -f "$MODE_FILE"
  rm -rf .claude/skills/hack-kickoff .specify/hack tests/hack || rollback graduate "remove hackathon tooling"

  info "graduated — the project now follows the full Spec-Driven flow (AGENTS.md §2)"
  info "inherited debt: $debt_count task(s) under '## Inherited debt' in $feature/tasks.md"
  [[ -n "$open_branches" ]] && warn "unmerged branches left untouched: $(echo $open_branches)"
  if [[ -n "$code_repo" ]]; then
    info "coordinating variant: adopt $code_repo in full mode — copy $feature/{spec,plan,tasks}.md into its specs/, run /kickoff there, then /speckit-converge"
  fi
  info "next: /speckit-converge, then commit: git add -A && git commit -m \"chore: graduate from hackathon mode\""
  rm -f scripts/hack.sh
}

# --- verify (called by scripts/verify.sh in hackathon mode) -------------------------------
verify_step() { # <label> <command>
  echo "verify: $1 — \$ $2"
  if ! eval "$2"; then
    echo "verify: $1 FAILED" >&2
    exit 1
  fi
}

cmd_verify() {
  local full=0 smoke build feature
  [[ "${1:-}" == "--full" ]] && full=1
  mode_active || die 3 "verify: not in hackathon mode — use scripts/verify.sh"
  verify_step check "scripts/hack.sh check"
  feature=$(mode_get feature_directory)
  if [[ "$(mode_get demo_check)" == automated ]]; then
    smoke=$(mode_get commands.smoke)
    verify_step smoke "$smoke"
  else
    echo "verify: smoke MANUAL — run the demo checklist in $feature/demo.md (not counted as passed)"
    [[ "${GITHUB_ACTIONS:-}" == "true" ]] && echo "::warning::demo check is MANUAL — run the checklist in $feature/demo.md"
  fi
  if [[ "$full" == 1 ]]; then
    build=$(mode_get commands.build)
    if [[ -n "$build" ]]; then verify_step build "$build"; else echo "verify: build not applicable (commands.build is null)"; fi
  fi
  echo "verify: OK"
}

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 3
}

cmd="${1:-}"
[[ $# -gt 0 ]] && shift
case "$cmd" in
  on | status | guard | check | verify | issues | hooks | graduate)
    fn="cmd_$cmd"
    if declare -F "$fn" >/dev/null; then "$fn" "$@"; else die 3 "$cmd: not implemented"; fi
    ;;
  *) usage ;;
esac
