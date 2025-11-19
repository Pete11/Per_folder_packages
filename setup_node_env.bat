@echo off
setlocal

REM ============================
REM Per-node env setup for Comfy
REM ============================

REM This .bat must sit inside a custom node folder:
REM ...\ComfyUI\custom_nodes\YourNode\setup_node_env.bat

set "NODE_DIR=%~dp0"
set "PYTHON_EXE=%NODE_DIR%..\..\..\python_embeded\python.exe"
set "TMP_PY=%NODE_DIR%_setup_node_env_tmp.py"

echo [node-env] Node folder: %NODE_DIR%

if not exist "%PYTHON_EXE%" (
    echo [node-env] ERROR: python.exe not found at:
    echo   "%PYTHON_EXE%"
    echo Edit PYTHON_EXE in this .bat if your layout is different.
    pause
    goto :eof
)

REM Clean old temp script if exists
if exist "%TMP_PY%" del "%TMP_PY%" >nul 2>&1

REM ============================
REM Generate temporary Python script
REM ============================

echo import sys, subprocess>>"%TMP_PY%"
echo from pathlib import Path>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo BLOCK_PREFIXES = (^"torch^", ^"torchvision^", ^"torchaudio^", ^"xformers^", ^"triton^")>>"%TMP_PY%"
echo SNIPPET_BEGIN = "# >>> NODE_LOCAL_DEPS_BEGIN >>>">>"%TMP_PY%"
echo SNIPPET_END = "# <<< NODE_LOCAL_DEPS_END <<<">>"%TMP_PY%"
echo SNIPPET = (>>"%TMP_PY%"
echo     "# >>> NODE_LOCAL_DEPS_BEGIN >>>\n">>"%TMP_PY%"
echo     "import os as _os, sys as _sys\n">>"%TMP_PY%"
echo     "_base = _os.path.dirname(__file__)\n">>"%TMP_PY%"
echo     "_pkg = _os.path.join(_base, \"_packages\")\n">>"%TMP_PY%"
echo     "if _os.path.isdir(_pkg) and _pkg not in _sys.path:\n">>"%TMP_PY%"
echo     "    _sys.path.insert(0, _pkg)\n">>"%TMP_PY%"
echo     "del _os, _sys, _base, _pkg\n">>"%TMP_PY%"
echo     "# <<< NODE_LOCAL_DEPS_END <<<\n">>"%TMP_PY%"
echo )>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo def log(msg: str):>>"%TMP_PY%"
echo     print(f"[node-env] {msg}")>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo def main():>>"%TMP_PY%"
echo     node_dir = Path(__file__).resolve().parent>>"%TMP_PY%"
echo     req_file = node_dir / "requirements.txt">>"%TMP_PY%"
echo     pkgs_dir = node_dir / "_packages">>"%TMP_PY%"
echo     init_file = node_dir / "__init__.py">>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     log(f"Node folder: {node_dir}")>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     if not req_file.exists():>>"%TMP_PY%"
echo         log(f"No requirements.txt at {req_file}, nothing to do.")>>"%TMP_PY%"
echo         return>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     pkgs_dir.mkdir(exist_ok=True)>>"%TMP_PY%"
echo     log(f"Using per-node packages folder: {pkgs_dir}")>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     raw_lines = req_file.read_text(encoding="utf-8").splitlines()>>"%TMP_PY%"
echo     kept = []>>"%TMP_PY%"
echo     skipped = []>>"%TMP_PY%"
echo     for line in raw_lines:>>"%TMP_PY%"
echo         stripped = line.strip()>>"%TMP_PY%"
echo         if not stripped or stripped.startswith("#"):>>"%TMP_PY%"
echo             kept.append(line)>>"%TMP_PY%"
echo             continue>>"%TMP_PY%"
echo         tok = stripped.split()[0]>>"%TMP_PY%"
echo         if any(tok.startswith(p) for p in BLOCK_PREFIXES):>>"%TMP_PY%"
echo             skipped.append(stripped)>>"%TMP_PY%"
echo             continue>>"%TMP_PY%"
echo         kept.append(line)>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     if skipped:>>"%TMP_PY%"
echo         log("Skipping global/shared dependencies (torch/xformers/triton/etc):")>>"%TMP_PY%"
echo         for s in skipped:>>"%TMP_PY%"
echo             log("  - " + s)>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     has_real = any(l.strip() and not l.strip().startswith("#") for l in kept)>>"%TMP_PY%"
echo     if has_real:>>"%TMP_PY%"
echo         filtered_req = node_dir / "_requirements_filtered.txt">>"%TMP_PY%"
echo         filtered_req.write_text("\n".join(kept) + "\n", encoding="utf-8")>>"%TMP_PY%"
echo         log(f"Filtered requirements written to: {filtered_req}")>>"%TMP_PY%"
echo         cmd = [>>"%TMP_PY%"
echo             sys.executable,>>"%TMP_PY%"
echo             "-m", "pip",>>"%TMP_PY%"
echo             "install",>>"%TMP_PY%"
echo             "--target", str(pkgs_dir),>>"%TMP_PY%"
echo             "-r", str(filtered_req),>>"%TMP_PY%"
echo         ]>>"%TMP_PY%"
echo         log("Running pip: " + " ".join(cmd))>>"%TMP_PY%"
echo         subprocess.check_call(cmd)>>"%TMP_PY%"
echo         log("pip install completed.")>>"%TMP_PY%"
echo     else:>>"%TMP_PY%"
echo         log("No installable requirements after filtering; skipping pip.")>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo     if not init_file.exists():>>"%TMP_PY%"
echo         log(f"__init__.py not found, creating at {init_file}")>>"%TMP_PY%"
echo         init_file.write_text(SNIPPET, encoding="utf-8")>>"%TMP_PY%"
echo         log("Written new __init__.py with local deps snippet.")>>"%TMP_PY%"
echo     else:>>"%TMP_PY%"
echo         text = init_file.read_text(encoding="utf-8")>>"%TMP_PY%"
echo         if SNIPPET_BEGIN in text:>>"%TMP_PY%"
echo             log("Local deps snippet already present; no changes.")>>"%TMP_PY%"
echo         else:>>"%TMP_PY%"
echo             log(f"Patching existing __init__.py at {init_file}")>>"%TMP_PY%"
echo             init_file.write_text(SNIPPET + "\n" + text, encoding="utf-8")>>"%TMP_PY%"
echo             log("Prepended local deps snippet to __init__.py.")>>"%TMP_PY%"
echo.>>"%TMP_PY%"
echo if __name__ == "__main__":>>"%TMP_PY%"
echo     main()>>"%TMP_PY%"

REM ============================
REM Run temporary Python script
REM ============================

"%PYTHON_EXE%" "%TMP_PY%"
set "ERR=%ERRORLEVEL%"

REM Cleanup temp script
if exist "%TMP_PY%" del "%TMP_PY%" >nul 2>&1

echo.
echo [node-env] Done with errorlevel %ERR%.
echo If there was an error, check the messages above.
echo.

pause
