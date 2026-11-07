"""Decide qué modelo hace cada papel según equipo.toml y lo que hay instalado en esta máquina."""

import argparse
import json
import os
import shutil
import sys
import tomllib
from pathlib import Path

ORDEN_NIVELES = ["fuerte", "medio", "barato"]
PAPELES = ["planificar", "coordinar", "desarrollador", "qa", "revisor", "cazabugs", "seguridad"]

# Señales de que un agente tiene la sesión iniciada. Si no se reconoce el agente, basta con que esté instalado.
CREDENCIALES = {
    "claude": (["~/.claude/.credentials.json"], ["ANTHROPIC_API_KEY"]),
    "codex": (["~/.codex/auth.json"], ["OPENAI_API_KEY"]),
}
PROVEEDOR_AGENTE = {"claude": "anthropic", "codex": "openai"}
AUTH_OPENCODE = "~/.local/share/opencode/auth.json"


def leer_texto(ruta: str) -> str:
    try:
        return Path(ruta).expanduser().read_text()
    except OSError:
        return ""


def leer_toml(ruta: Path) -> dict:
    with ruta.open("rb") as f:
        return tomllib.load(f)


def mezclar(base: dict, encima: dict) -> dict:
    resultado = dict(base)
    for clave, valor in encima.items():
        if isinstance(valor, dict) and isinstance(resultado.get(clave), dict):
            resultado[clave] = mezclar(resultado[clave], valor)
        else:
            resultado[clave] = valor
    return resultado


def cargar(raiz: Path) -> tuple[dict, list[str]]:
    rutas = [raiz / "equipo.toml"]
    propia = Path(os.environ.get("TALLER_CONFIG", "~/.config/taller/equipo.toml")).expanduser()
    config = leer_toml(rutas[0])
    if propia.is_file():
        config = mezclar(config, leer_toml(propia))
        rutas.append(propia)
    return config, [str(r) for r in rutas]


def partir(entrada: str) -> tuple[str, str]:
    agente, _, modelo = entrada.partition(":")
    return agente.strip(), modelo.strip()


def proveedor(entrada: str) -> str:
    agente, modelo = partir(entrada)
    if agente in PROVEEDOR_AGENTE:
        return PROVEEDOR_AGENTE[agente]
    if "/" in modelo:
        return modelo.split("/", 1)[0].removesuffix("-coding-plan")
    return agente


def disponibilidad(entrada: str, sin: set[str]) -> str | None:
    """Devuelve None si se puede usar, o el motivo por el que no."""
    agente, modelo = partir(entrada)
    if entrada in sin or agente in sin or proveedor(entrada) in sin:
        return "marcado sin uso"
    if not shutil.which(agente):
        return f"{agente} no instalado"
    if agente in CREDENCIALES:
        archivos, variables = CREDENCIALES[agente]
        sesion = any(Path(a).expanduser().exists() for a in archivos) or any(os.environ.get(v) for v in variables)
        if agente == "claude" and not sesion:
            sesion = '"oauthAccount"' in leer_texto("~/.claude.json")
        if not sesion:
            return f"{agente} sin sesión iniciada"
    if agente == "opencode" and "/" in modelo:
        prov = modelo.split("/", 1)[0]
        variable = prov.upper().replace("-", "_") + "_API_KEY"
        auth = Path(AUTH_OPENCODE).expanduser()
        claves = {}
        if auth.is_file():
            try:
                claves = json.loads(auth.read_text())
            except (OSError, ValueError):
                claves = {}
        if prov not in claves and not os.environ.get(variable):
            return f"opencode sin credenciales de {prov}"
    return None


def candidatos(config: dict, papel: str) -> tuple[str | None, list[str]]:
    valor = config["papeles"].get(papel)
    if valor is None:
        raise SystemExit(f"El papel «{papel}» no está en [papeles].")
    if isinstance(valor, list):
        return None, valor
    if valor not in config["niveles"]:
        raise SystemExit(f"El papel «{papel}» pide el nivel «{valor}», que no está en [niveles].")
    return valor, list(config["niveles"][valor])


def resolver(config: dict, sin: set[str]) -> dict:
    reglas = config.get("reglas", {})
    esfuerzo = config.get("esfuerzo", {})
    motivos: dict[str, str] = {}
    papeles: dict[str, dict] = {}

    def disponibles(lista: list[str]) -> list[str]:
        libres = []
        for entrada in lista:
            motivo = disponibilidad(entrada, sin)
            if motivo:
                motivos[entrada] = motivo
            else:
                libres.append(entrada)
        return libres

    for papel in PAPELES:
        nivel, lista = candidatos(config, papel)
        libres = disponibles(lista)
        estado = "ok"
        nivel_usado = nivel
        if not libres and nivel and reglas.get("si_no_queda_nivel", "pausar") == "bajar":
            for inferior in ORDEN_NIVELES[ORDEN_NIVELES.index(nivel) + 1:] if nivel in ORDEN_NIVELES else []:
                libres = disponibles(config["niveles"].get(inferior, []))
                if libres:
                    estado, nivel_usado = "bajado", inferior
                    break
        if not libres:
            papeles[papel] = {"nivel": nivel, "estado": "pausar", "agente": None, "modelo": None, "reservas": []}
            continue
        elegido = libres[0]
        if papel == "revisor" and reglas.get("revisor_otro_proveedor", True):
            dev = papeles.get("desarrollador", {})
            if dev.get("agente"):
                prov_dev = proveedor(f"{dev['agente']}:{dev['modelo']}")
                distinto = next((e for e in libres if proveedor(e) != prov_dev), None)
                elegido = distinto or elegido
        agente, modelo = partir(elegido)
        papeles[papel] = {
            "nivel": nivel_usado,
            "estado": estado,
            "agente": agente,
            "modelo": modelo,
            "proveedor": proveedor(elegido),
            "esfuerzo": esfuerzo.get(papel, esfuerzo.get("defecto", "medium")),
            "reservas": [e for e in libres if e != elegido],
        }
    return {"papeles": papeles, "no_disponibles": motivos}


def imprimir(resultado: dict, rutas: list[str]) -> None:
    print("Configuración: " + " + ".join(rutas))
    print()
    print(f"{'Papel':<14} {'Nivel':<8} {'Usará':<42} Reservas")
    for papel, datos in resultado["papeles"].items():
        if datos["estado"] == "pausar":
            usara = "— ninguno disponible: se pausará"
        else:
            usara = f"{datos['agente']}:{datos['modelo']}"
            if datos["estado"] == "bajado":
                usara += " (nivel bajado)"
        reservas = ", ".join(datos["reservas"]) or "—"
        print(f"{papel:<14} {str(datos['nivel'] or 'lista'):<8} {usara:<42} {reservas}")
    if resultado["no_disponibles"]:
        print()
        print("No disponibles ahora:")
        for entrada, motivo in resultado["no_disponibles"].items():
            print(f"  {entrada}: {motivo}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raiz", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--sin", default=os.environ.get("TALLER_SIN", ""),
                        help="agentes, proveedores o modelos sin uso, separados por comas (p. ej. claude)")
    args = parser.parse_args()
    config, rutas = cargar(Path(args.raiz))
    sin = {s.strip() for s in args.sin.split(",") if s.strip()}
    resultado = resolver(config, sin)
    if args.json:
        json.dump(resultado, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        imprimir(resultado, rutas)
    return 0


if __name__ == "__main__":
    sys.exit(main())
