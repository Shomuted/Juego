#!/usr/bin/env python3
"""Importa y prueba el proyecto con partidas temporales; no toca los saves del jugador."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
TESTS = {
    "test_progresion.gd": r"PROGRESIÓN: (\d+) pruebas, 0 fallos",
    "test_campana.gd": r"CAMPAÑA: (\d+) pruebas, 0 fallos",
    "test_estanteria.gd": r"RESULTADO: (\d+) comprobaciones, 0 fallos\.",
    "test_formatos.gd": r"SPRINT 04: (\d+) comprobaciones, 0 fallos\.",
    "test_formato_fisica.gd": r"FORMATOS FÍSICOS: (\d+) pruebas, 0 errores",
    "test_guardado.gd": r"PRUEBAS: (\d+), FALLOS: 0",
    "test_persistencia.gd": r"PERSISTENCIA: (\d+) pruebas, 0 fallos",
    "test_interaccion.gd": r"INTERACCIÓN: (\d+) pruebas, 0 fallos",
}


def run(label: str, command: list[str], env: dict[str, str], marker: str = "") -> int:
    print(f"Comprobando {label}...", flush=True)
    result = subprocess.run(
        command, cwd=ROOT, env=env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90,
    )
    output = result.stdout
    match = re.search(marker, output) if marker else None
    engine_error = re.search(r"^(?:SCRIPT ERROR:|ERROR:)", output, re.MULTILINE)
    if result.returncode != 0 or engine_error or (marker and not match):
        print(output)
        raise RuntimeError(f"Falló {label} (salida {result.returncode}); consulta el registro anterior.")
    for line in output.splitlines():
        if line.startswith("WARNING:"):
            print(line)
    count = int(match.group(1)) if match and match.lastindex else 0
    if match and match.lastindex and count == 0:
        raise RuntimeError(f"{label} no ejecutó ninguna comprobación.")
    print(f"OK: {label}" + (f" ({count} comprobaciones)" if count else ""), flush=True)
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    args = parser.parse_args()
    executable = shutil.which(args.godot)
    if not executable:
        parser.error("No se encontró Godot. Instala Godot 4 o usa --godot /ruta/al/ejecutable.")

    # El directorio único impide que las pruebas lean, sobreescriban o borren
    # la partida normal. /tmp también satisface el guardrail del test de reset.
    with tempfile.TemporaryDirectory(prefix="tlps-checks-", dir="/tmp") as temporary:
        base = Path(temporary)
        env = os.environ.copy()
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        for variable, name in [("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
            directory = base / name
            directory.mkdir()
            env[variable] = str(directory)

        def isolate(name: str) -> dict[str, str]:
            isolated = env.copy()
            directory = base / name
            directory.mkdir()
            isolated["XDG_DATA_HOME"] = str(directory)
            isolated["TLPS_TEST_USER_DIR"] = str(
                directory / "godot" / "app_userdata" / "The Last Physical Store"
            )
            return isolated

        run("importación Godot", [executable, "--headless", "--path", str(ROOT),
            "--editor", "--import", "--quit"], isolate("import"))
        run("catálogo SQLite", [sys.executable, "-m", "unittest", "discover",
            "-s", "Tests", "-p", "test_schema_contract.py", "-v"], env,
            r"Ran ([1-9]\d*) tests? in [\s\S]*\bOK\b")

        total = 0
        for script, marker in TESTS.items():
            total += run(script, [executable, "--headless", "--path", str(ROOT),
                "--script", f"res://Tests/{script}"], isolate(script), marker)

        # Mismo user:// temporal, dos procesos independientes: comprueba que la
        # reconstrucción no depende de nodos ni estado retenido por el proceso.
        reopening = isolate("reopening")
        for phase, marker in [("escribir", "ESCRITURA"), ("leer", "LECTURA")]:
            total += run(f"reapertura: {phase}", [executable, "--headless", "--path",
                str(ROOT), "--script", "res://Tests/test_persistencia.gd", "--",
                f"--{phase}-reapertura"], reopening,
                rf"REAPERTURA {marker}: (\d+) pruebas, 0 fallos")

        run("inicio de partida (120 fotogramas)", [executable, "--headless",
            "--path", str(ROOT), "--quit-after", "120"], isolate("startup"),
            r"Nueva partida\. TAB:")
        print(f"Validación terminada: {total} comprobaciones Godot y catálogo SQLite aprobados.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
