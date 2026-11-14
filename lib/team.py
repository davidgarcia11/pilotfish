"""Decide which model plays each role, from team.toml and what is installed on this machine."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

TIER_ORDER = ["strong", "standard", "budget"]
TEAM_MODES = ["ask", "full", "necessary", "minimal"]
EFFORTS = ["low", "medium", "high"]
PRESET_ALIASES = {"calidad": "quality", "equilibrado": "balanced", "ahorro": "saving"}
PROJECT_FILE = ".pilotfish.toml"
OTHER_AGENTS = ["cursor-agent", "gemini", "agy", "grok"]
ROLES = ["plan", "coordinate", "developer", "qa", "reviewer", "bug_hunter", "security"]

# Signs that an agent is logged in. Unknown agents only need to be installed.
CREDENTIALS = {
    "claude": (["~/.claude/.credentials.json"], ["ANTHROPIC_API_KEY"]),
    "codex": (["~/.codex/auth.json"], ["OPENAI_API_KEY"]),
}
AGENT_PROVIDER = {"claude": "anthropic", "codex": "openai"}
OPENCODE_AUTH = "~/.local/share/opencode/auth.json"
_opencode_models: dict[str, set[str] | None] = {}


def opencode_models(prov: str) -> set[str] | None:
    """Models OpenCode offers for a provider, or None if it can't tell."""
    if prov not in _opencode_models:
        try:
            out = subprocess.run(["opencode", "models", prov], capture_output=True, text=True, timeout=30)
            names = {line.strip() for line in out.stdout.splitlines() if line.strip().startswith(prov + "/")}
            _opencode_models[prov] = names if out.returncode == 0 and names else None
        except (OSError, subprocess.SubprocessError):
            _opencode_models[prov] = None
    return _opencode_models[prov]


def read_text(path: str) -> str:
    try:
        return Path(path).expanduser().read_text()
    except OSError:
        return ""


def read_toml(path: Path) -> dict:
    with path.open("rb") as f:
        return tomllib.load(f)


def merge(base: dict, override: dict) -> dict:
    result = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result


def project_config_path() -> Path | None:
    """The project's own settings: .pilotfish.toml in the main checkout, shared by its worktrees."""
    if os.environ.get("PILOTFISH_PROJECT_CONFIG"):
        return Path(os.environ["PILOTFISH_PROJECT_CONFIG"]).expanduser()
    try:
        out = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                             capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    return Path(out.stdout.strip()).parent / PROJECT_FILE if out.returncode == 0 else None


def load(root: Path) -> tuple[dict, list[str]]:
    """Defaults, then the user's settings, then the project's: each layer overrides the previous one."""
    paths = [root / "team.toml"]
    config = read_toml(paths[0])
    own = Path(os.environ.get("PILOTFISH_CONFIG", "~/.config/pilotfish/team.toml")).expanduser()
    for layer in (own, project_config_path()):
        if layer and layer.is_file():
            config = merge(config, read_toml(layer))
            paths.append(layer)
    return config, [str(p) for p in paths]


def preset_roles(config: dict, name: str) -> dict:
    name = PRESET_ALIASES.get(name, name)
    presets = config.get("presets", {})
    if name not in presets:
        raise SystemExit(f"Unknown preset «{name}». Presets: {', '.join(presets)}.")
    return dict(presets[name])


def detect(config: dict) -> dict:
    """Every model Pilotfish could use on this machine, available or not, and other agents found."""
    entries: list[str] = []
    lists = list(config["tiers"].values()) + [v for v in config["roles"].values() if isinstance(v, list)]
    for entry in (e for group in lists for e in group):
        if entry not in entries:
            entries.append(entry)
    if shutil.which("opencode"):
        auth = Path(OPENCODE_AUTH).expanduser()
        try:
            providers = sorted(json.loads(auth.read_text())) if auth.is_file() else []
        except (OSError, ValueError):
            providers = []
        for prov in providers:
            for model in sorted(opencode_models(prov) or []):
                if f"opencode:{model}" not in entries:
                    entries.append(f"opencode:{model}")
    available, unavailable = [], {}
    for entry in entries:
        reason = unavailable_reason(entry, set())
        if reason:
            unavailable[entry] = reason
        else:
            available.append(entry)
    return {"available": available, "unavailable": unavailable,
            "other_agents": [a for a in OTHER_AGENTS if shutil.which(a)]}


def parse_role_value(config: dict, role: str, value: str) -> str | list[str]:
    if role not in ROLES:
        raise SystemExit(f"Unknown role «{role}». Roles: {', '.join(ROLES)}.")
    if value in config["tiers"]:
        return value
    entries = [e.strip() for e in value.split(",") if e.strip()]
    bad = [e for e in entries if ":" not in e]
    if not entries or bad:
        raise SystemExit(f"«{value}» is neither a tier ({', '.join(config['tiers'])}) "
                         "nor a list of agent:model separated by commas.")
    return entries


def toml_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(v) for v in value) + "]"
    return json.dumps(value, ensure_ascii=False)


def write_project(path: Path, data: dict) -> None:
    lines = ["# This project's team in Pilotfish. It overrides your settings and the defaults.",
             "# Local file, outside git. Change it with `pilotfish config` or `pilotfish set`, or ask the coordinator.",
             ""]
    for section in ("roles", "effort", "rules", "tiers"):
        if data.get(section):
            lines.append(f"[{section}]")
            lines += [f"{key} = {toml_value(value)}" for key, value in data[section].items()]
            lines.append("")
    path.write_text("\n".join(lines))


def set_project(config: dict, path: Path, preset: str | None, roles: list[str], mode: str | None,
                efforts: list[str]) -> None:
    data = read_toml(path) if path.is_file() else {}
    if preset:
        data["roles"] = preset_roles(config, preset)
    for item in roles:
        role, _, value = item.partition("=")
        data.setdefault("roles", {})[role.strip()] = parse_role_value(config, role.strip(), value.strip())
    if mode:
        if mode not in TEAM_MODES:
            raise SystemExit(f"team_mode «{mode}» is not one of: {', '.join(TEAM_MODES)}.")
        data.setdefault("rules", {})["team_mode"] = mode
    for item in efforts:
        role, _, level = item.partition("=")
        if role.strip() not in ROLES + ["default"] or level.strip() not in EFFORTS:
            raise SystemExit(f"«{item}»: use ROLE=LEVEL, with a role or default and one of {', '.join(EFFORTS)}.")
        data.setdefault("effort", {})[role.strip()] = level.strip()
    write_project(path, data)


def split(entry: str) -> tuple[str, str]:
    agent, _, model = entry.partition(":")
    return agent.strip(), model.strip()


def provider(entry: str) -> str:
    agent, model = split(entry)
    if agent in AGENT_PROVIDER:
        return AGENT_PROVIDER[agent]
    if "/" in model:
        return model.split("/", 1)[0].removesuffix("-coding-plan")
    return agent


def unavailable_reason(entry: str, without: set[str]) -> str | None:
    """None if the model can be used, otherwise why not."""
    agent, model = split(entry)
    if entry in without or agent in without or provider(entry) in without:
        return "excluded (out of usage)"
    if not shutil.which(agent):
        return f"{agent} not installed"
    if agent in CREDENTIALS:
        files, variables = CREDENTIALS[agent]
        logged_in = any(Path(f).expanduser().exists() for f in files) or any(os.environ.get(v) for v in variables)
        if agent == "claude" and not logged_in:
            logged_in = '"oauthAccount"' in read_text("~/.claude.json")
        if not logged_in:
            return f"{agent} not logged in"
    if agent == "opencode" and "/" in model:
        prov = model.split("/", 1)[0]
        variable = prov.upper().replace("-", "_") + "_API_KEY"
        keys = {}
        auth = Path(OPENCODE_AUTH).expanduser()
        if auth.is_file():
            try:
                keys = json.loads(auth.read_text())
            except (OSError, ValueError):
                keys = {}
        if prov not in keys and not os.environ.get(variable):
            return f"opencode has no credentials for {prov}"
        offered = opencode_models(prov)
        if offered is not None and model not in offered:
            return f"opencode does not offer {model} (see `opencode models {prov}`)"
    return None


def candidates(config: dict, role: str) -> tuple[str | None, list[str]]:
    value = config["roles"].get(role)
    if value is None:
        raise SystemExit(f"Role «{role}» is missing from [roles].")
    if isinstance(value, list):
        return None, value
    if value not in config["tiers"]:
        raise SystemExit(f"Role «{role}» asks for tier «{value}», which is missing from [tiers].")
    return value, list(config["tiers"][value])


def resolve(config: dict, without: set[str]) -> dict:
    rules = config.get("rules", {})
    effort = config.get("effort", {})
    reasons: dict[str, str] = {}
    roles: dict[str, dict] = {}

    def available(entries: list[str]) -> list[str]:
        free = []
        for entry in entries:
            reason = unavailable_reason(entry, without)
            if reason:
                reasons[entry] = reason
            else:
                free.append(entry)
        return free

    for role in ROLES:
        tier, entries = candidates(config, role)
        free = available(entries)
        status, tier_used = "ok", tier
        if not free and tier in TIER_ORDER and rules.get("when_tier_exhausted", "pause") == "downgrade":
            for lower in TIER_ORDER[TIER_ORDER.index(tier) + 1:]:
                free = available(config["tiers"].get(lower, []))
                if free:
                    status, tier_used = "downgraded", lower
                    break
        if not free:
            roles[role] = {"tier": tier, "status": "paused", "agent": None, "model": None, "fallbacks": []}
            continue
        chosen = free[0]
        if role == "reviewer" and rules.get("reviewer_different_provider", True):
            dev = roles.get("developer", {})
            if dev.get("agent"):
                dev_provider = provider(f"{dev['agent']}:{dev['model']}")
                chosen = next((e for e in free if provider(e) != dev_provider), chosen)
        agent, model = split(chosen)
        roles[role] = {
            "tier": tier_used,
            "status": status,
            "agent": agent,
            "model": model,
            "provider": provider(chosen),
            "effort": effort.get(role, effort.get("default", "medium")),
            "fallbacks": [e for e in free if e != chosen],
        }
    team_mode = rules.get("team_mode", "ask")
    if team_mode not in TEAM_MODES:
        raise SystemExit(f"team_mode «{team_mode}» is not one of: {', '.join(TEAM_MODES)}.")
    return {"team_mode": team_mode, "roles": roles, "unavailable": reasons}


def show(result: dict, paths: list[str]) -> None:
    print("Config: " + " + ".join(paths))
    print(f"Team mode: {result['team_mode']}")
    print()
    print(f"{'Role':<12} {'Tier':<9} {'Uses':<42} Fallbacks")
    for role, data in result["roles"].items():
        if data["status"] == "paused":
            uses = "— none available: will pause"
        else:
            uses = f"{data['agent']}:{data['model']}" + (" (downgraded)" if data["status"] == "downgraded" else "")
        print(f"{role:<12} {str(data['tier'] or 'list'):<9} {uses:<42} {', '.join(data['fallbacks']) or '—'}")
    if result["unavailable"]:
        print()
        print("Unavailable right now:")
        for entry, reason in result["unavailable"].items():
            print(f"  {entry}: {reason}")


def show_detect(found: dict) -> None:
    print("Available on this machine:")
    for entry in found["available"]:
        print(f"  {entry}")
    if found["unavailable"]:
        print()
        print("Known but unavailable:")
        for entry, reason in found["unavailable"].items():
            print(f"  {entry}: {reason}")
    if found["other_agents"]:
        print()
        print("Other agents installed (add them to a role as agent:model): " + ", ".join(found["other_agents"]))


def ask(prompt: str) -> str:
    try:
        return input(prompt).strip()
    except EOFError:
        return ""


def interactive(config: dict, path: Path, without: set[str]) -> None:
    """Terminal assistant: pick a starting point, adjust roles, choose the team mode, save for this project."""
    found = detect(config)
    print(f"Team for the project at {path.parent}\n")
    show_detect(found)
    names = list(config.get("presets", {}))
    print("\nStarting points:")
    for n, name in enumerate(names, 1):
        roles = resolve(merge(config, {"roles": preset_roles(config, name)}), without)["roles"]
        summary = ", ".join(f"{r}={d['model'] or 'paused'}" for r, d in roles.items())
        print(f"  {n}. {name}: {summary}")
    choice = ask(f"Starting point [1-{len(names)}, Enter keeps the current one]: ")
    preset = names[int(choice) - 1] if choice.isdigit() and 1 <= int(choice) <= len(names) else None
    role_changes: list[str] = []
    available = found["available"]
    while True:
        role = ask(f"Change a role? ({', '.join(ROLES)}; Enter to finish): ")
        if not role:
            break
        if role not in ROLES:
            print("  Unknown role.")
            continue
        for n, entry in enumerate(available, 1):
            print(f"  {n}. {entry}")
        picks = ask("  Models in priority order, as numbers separated by commas: ")
        chosen = [available[int(x) - 1] for x in picks.replace(" ", "").split(",")
                  if x.isdigit() and 1 <= int(x) <= len(available)]
        if chosen:
            role_changes.append(f"{role}={','.join(chosen)}")
    mode = ask(f"Team mode ({', '.join(TEAM_MODES)}; Enter keeps the current one): ") or None
    if not (preset or role_changes or mode):
        print("\nNothing changed.\n")
        return
    set_project(config, path, preset, role_changes, mode, [])
    print(f"\nSaved in {path}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--without", default=os.environ.get("PILOTFISH_WITHOUT", ""),
                        help="agents, providers or models out of usage, comma-separated (e.g. claude)")
    parser.add_argument("--detect", action="store_true", help="list every model usable on this machine")
    parser.add_argument("--preset", help="preview a starting point, or apply it with --save")
    parser.add_argument("--save", action="store_true", help="write the changes to the project's .pilotfish.toml")
    parser.add_argument("--role", action="append", default=[], help="ROLE=tier or ROLE=agent:model,agent:model")
    parser.add_argument("--mode", help="team mode: " + ", ".join(TEAM_MODES))
    parser.add_argument("--effort", action="append", default=[], help="ROLE=low|medium|high")
    parser.add_argument("--interactive", action="store_true")
    args = parser.parse_args()
    root = Path(args.root)
    config, paths = load(root)
    without = {w.strip() for w in args.without.split(",") if w.strip()}

    if args.detect:
        found = detect(config)
        json.dump(found, sys.stdout, ensure_ascii=False, indent=2) if args.json else show_detect(found)
        print() if args.json else None
        return 0
    if args.save or args.interactive:
        path = project_config_path()
        if path is None:
            raise SystemExit("Not inside a git repository: run it from the project's folder.")
        if args.interactive:
            interactive(config, path, without)
        else:
            set_project(config, path, args.preset, args.role, args.mode, args.effort)
        config, paths = load(root)
    elif args.preset:
        config = merge(config, {"roles": preset_roles(config, args.preset)})
    result = resolve(config, without)
    if args.json:
        json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        show(result, paths)
    return 0


if __name__ == "__main__":
    sys.exit(main())
