@echo off
rem ============================================================
rem build.bat (Member D) - joins the module files, in order, into
rem ONE source file. Run it from the repo root (the folder that
rem contains src\ and tests\).
rem A blank line is added after every file so a file that does not
rem end with a newline can never glue onto the next file.
rem ============================================================
if not exist build mkdir build
if exist build\NotPython.asm del build\NotPython.asm

set RULES=src\50_rules.asm
if not exist %RULES% (
    set RULES=tests\50_rules_stub.asm
    echo WARNING: src\50_rules.asm not found - using tests\50_rules_stub.asm
)

for %%F in (src\00_header.asm src\10_data.asm src\20_main.asm src\30_gfx.asm src\40_snake.asm %RULES% src\60_ui.asm src\90_footer.asm) do (
    if not exist %%F goto fail
    type %%F >> build\NotPython.asm
    echo.>> build\NotPython.asm
)

copy /y build\NotPython.asm build\Section_GroupName_MP.txt > nul
echo Built build\NotPython.asm and build\Section_GroupName_MP.txt
goto end

:fail
echo BUILD FAILED: a module file is missing (see the message above)

:end
