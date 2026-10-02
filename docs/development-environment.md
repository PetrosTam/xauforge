# Development Environment

XAUForge uses a dedicated MetaTrader 5 installation in portable mode while keeping the Git repository as the source of truth for project-controlled source code.

This document describes the verified local development/build environment. It does not define trading strategy, risk policy, or execution behavior; those responsibilities are documented elsewhere.

## Verified Environment

The current development workflow has been verified with:

- MetaTrader 5 version 5.00, build 6231, 27 Sep 2026
- MetaEditor version 5.00, build 6231, 27 Sep 2026
- MetaEditor CPU target: X64 Regular
- Active-development compilation: No Optimization
- Compile quality gate: 0 errors and 0 warnings

MetaTrader 5 can update independently through its platform update mechanism. The environment is therefore not treated as a bit-for-bit frozen toolchain.

After a meaningful MetaTrader 5 or MetaEditor build change, representative build and test baselines should be rerun and the new build information recorded.

## Directory Model

The verified local development layout is:

```text
C:\Dev\xauforge       Git working tree and source of truth
C:\MT5\XAUForge       Dedicated MT5 and MetaEditor installation
```

The complete MT5 installation is intentionally outside the Git repository.

The dedicated MT5 directory can contain runtime state such as:

- terminal configuration,
- account-related configuration,
- broker history,
- cache,
- logs,
- profiles,
- tester data,
- other platform-generated state.

These runtime files are not part of the Git-controlled project source.

## Portable Mode

The dedicated terminal is launched in portable mode:

```powershell
Start-Process "C:\MT5\XAUForge\terminal64.exe" -ArgumentList "/portable"
```

MetaEditor is launched against the same dedicated installation:

```powershell
Start-Process "C:\MT5\XAUForge\MetaEditor64.exe" -ArgumentList "/portable"
```

For the verified installation, both MetaTrader 5 and MetaEditor resolve their data directory to:

```text
C:\MT5\XAUForge
```

Portable mode isolates the project-specific terminal data location, but it does not freeze the installed MetaTrader build.

## Git Source of Truth

Project-controlled MQL5 source remains inside the repository:

```text
mql5\
├── Experts\
│   └── XAUForge\
│       ├── XAUForge.mq5
│       └── XAUForge.mqproj
└── Include\
    └── XAUForge\
        ├── StrategyEngine.mqh
        ├── SymbolManager.mqh
        └── RiskManager.mqh
```

This tree reflects the current repository state after Phase 6. Later roadmap files are not created early merely because they appear in the target repository structure.

The repository is the authoritative location for project-controlled source, configuration, scripts, and documentation.

The MT5 installation is a development/runtime environment and is not the source of truth.

## Repository-to-MT5 Linkage

MetaTrader expects MQL5 applications inside its own `MQL5` directory structure.

XAUForge keeps the Git repository separate from the MT5 installation and exposes the repository-controlled source to MT5 through Windows directory junctions.

The verified mappings are:

```text
C:\MT5\XAUForge\MQL5\Experts\XAUForge
    -> C:\Dev\xauforge\mql5\Experts\XAUForge

C:\MT5\XAUForge\MQL5\Include\XAUForge
    -> C:\Dev\xauforge\mql5\Include\XAUForge
```

Create or verify this linkage from the repository root with:

```powershell
.\scripts\setup-mt5.ps1 -Mt5Root "C:\MT5\XAUForge"
```

The MT5 installation path is supplied as a parameter rather than being hard-coded into the script.

The repository root is derived by the script from its own location.

## Setup Script Behavior

`scripts/setup-mt5.ps1` verifies the expected MT5 installation structure and manages the repository-to-MT5 junctions.

The script has been verified to:

- detect the required MT5 installation directory,
- verify `terminal64.exe`,
- verify `MetaEditor64.exe`,
- verify the MT5 `MQL5` directory,
- reject an MT5 installation located inside the Git repository,
- create missing repository-to-MT5 junctions,
- recognize already-correct junctions without recreating them,
- reject junctions that point to an unexpected target,
- reject normal directories that conflict with an expected junction,
- preserve conflicting directories instead of deleting or replacing them.

The setup process is intentionally non-destructive. Unexpected filesystem state causes a safe failure instead of forced modification.

## MetaEditor Project

The local MetaEditor project definition is:

```text
mql5\Experts\XAUForge\XAUForge.mqproj
```

The project is configured as an Expert Advisor and currently uses:

- X64 Regular CPU target,
- No Optimization during active development,
- floating-point divider checks enabled.

The project uses:

```text
XAUForge.mq5
```

as the relative compile target. Project headers are reached through the MQL5 include path and repository-to-MT5 linkage.

The `.mqproj` file is the project-level build definition. Project-controlled build settings should not be duplicated inconsistently in source files.

## Initial Compile-Loop Baseline

During the Phase 1 / Phase 2 environment bootstrap, the build loop was intentionally verified with a minimal Expert Advisor:

```mql5
int OnInit()
{
   return(INIT_SUCCEEDED);
}
```

That snippet is historical bootstrap evidence, not the current `XAUForge.mq5` implementation.

The current EA has progressed through lifecycle, strategy, symbol/account capability, and RiskManager phases while retaining the same verified repository-to-MT5 build path.

The purpose of the original minimal target was to prove the development/build loop before trading behavior was introduced.

## Command-Line Build

Compile XAUForge from the repository root with:

```powershell
.\scripts\build-mql5.ps1 -Mt5Root "C:\MT5\XAUForge"
```

The wrapper invokes the installed MetaEditor against:

```text
XAUForge.mqproj
```

rather than treating the main `.mq5` source file as the authoritative build configuration.

The verified MetaEditor command-line workflow uses the project file together with the MT5 `MQL5` include directory and a generated compilation log.

## Build Validation

Before each build result is evaluated, the wrapper removes the previous generated compilation log.

This prevents a stale successful log from being mistaken for the result of a new compilation.

After MetaEditor finishes, the wrapper requires a newly generated log and extracts the compiler result from a line of the form:

```text
Result: <errors> errors, <warnings> warnings, ...
```

The build passes only when the compiler reports:

```text
0 errors, 0 warnings
```

Any error or warning causes the build wrapper to fail.

The compile gate is therefore stricter than merely checking whether an `.ex5` file was produced.

## MetaEditor Process Exit Code

With the verified MetaEditor build 6231, the process exit code did not reliably represent compilation success or failure during validation.

Observed behavior included:

```text
successful compile -> process exit code 1
failed compile     -> process exit code 0
```

For this reason, `scripts/build-mql5.ps1` records the process exit code for diagnostics but does not use it as the compile quality gate.

The authoritative build result for this verified workflow is the fresh MetaEditor compilation log.

This behavior should be revalidated after meaningful MetaEditor build changes.

## Generated Build Artifacts

MetaEditor generates local build artifacts such as:

```text
XAUForge.ex5
XAUForge.log
```

These files are generated outputs and are not project source.

They are ignored by Git through repository ignore rules.

A normal build must not result in generated `.ex5` binaries or compilation logs being staged or committed.

## Verified Build Behavior

The command-line build workflow has been tested for both successful and failing compilation.

Successful project compilation produced:

```text
0 errors, 0 warnings
```

with:

```text
without optimizations
cpu='X64 Regular'
```

An intentionally introduced MQL5 syntax error produced compiler errors and was correctly rejected by the build wrapper.

After restoring the source, the same wrapper successfully rebuilt the project with:

```text
0 errors, 0 warnings
```

The same compile gate continued to pass after the Phase 6 RiskManager implementation was merged.

This verifies both the success path and the compile-failure rejection path while keeping the build workflow stable as the EA grows.

## Development Workflow

For MQL5 work:

1. Work from the Git repository.
2. Edit project-controlled source in the repository tree.
3. Run `scripts/setup-mt5.ps1` when the local MT5 linkage must be created or verified.
4. Run `scripts/build-mql5.ps1` when MQL5 source or project build behavior is affected.
5. Require 0 errors and 0 warnings.
6. Run the relevant logic / Strategy Tester / regression validation for the current phase.
7. Review `git status`.
8. Review the relevant diff.
9. Stage only the intended paths.
10. Review the staged diff.
11. Run the relevant validation again when necessary.
12. Create one atomic Conventional Commit for the logical change.

Manual MetaEditor compilation can still be useful during development, but the PowerShell wrapper provides the repeatable repository-level build path.

Documentation-only changes do not require an MQL5 rebuild unless the documentation claim itself depends on a newly observed build result.

## Git Safety Rules

Do not commit:

- generated `.ex5` binaries,
- compilation logs,
- terminal logs,
- MT5 runtime directories,
- broker history or cache,
- account configuration,
- credentials or secrets,
- terminal profiles,
- tester runtime state,
- machine-specific runtime data,
- personal absolute paths embedded in project-controlled source.

The dedicated MT5 installation remains outside the Git repository.

## Recreating the Development Linkage

A developer with:

- the XAUForge repository,
- a dedicated MetaTrader 5 installation,
- PowerShell,
- an appropriate Windows environment,

should be able to recreate the repository-to-MT5 linkage by running:

```powershell
.\scripts\setup-mt5.ps1 -Mt5Root "<path-to-dedicated-mt5>"
```

and then validate the build with:

```powershell
.\scripts\build-mql5.ps1 -Mt5Root "<path-to-dedicated-mt5>"
```

The scripts must receive the local MT5 installation path as input rather than depending on a specific developer's machine layout.

## Environment Change Policy

MetaTrader 5 can update independently of the repository.

After a meaningful MT5 or MetaEditor update:

1. record the new platform build information,
2. rerun the setup verification,
3. rerun the command-line compile baseline,
4. confirm the compile gate still reports 0 errors and 0 warnings,
5. revalidate any version-sensitive command-line behavior,
6. rerun representative later-stage tests when they exist.

This keeps the development process reproducible without claiming that the MetaTrader platform itself is permanently frozen.
