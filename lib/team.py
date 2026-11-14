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


def load(root: Path) -> tuple[dict, list[str]]:
    paths = [root / "team.toml"]
    own = Path(os.environ.get("PILOTFISH_CONFIG", "~/.config/pilotfish/team.toml")).expanduser()
    config = read_toml(paths[0])
    if own.is_file():
        config = merge(config, read_toml(own))
        paths.append(own)
    return config, [str(p) for p in paths]


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--without", default=os.environ.get("PILOTFISH_WITHOUT", ""),
                        help="agents, providers or models out of usage, comma-separated (e.g. claude)")
    args = parser.parse_args()
    config, paths = load(Path(args.root))
    without = {w.strip() for w in args.without.split(",") if w.strip()}
    result = resolve(config, without)
    if args.json:
        json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        show(result, paths)
    return 0


if __name__ == "__main__":
    sys.exit(main())
