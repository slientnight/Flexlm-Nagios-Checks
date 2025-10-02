# Nagios Checks for FLEXlm and RLM

This repository provides hardened Nagios plugins for monitoring FLEXlm and RLM
license servers. Each plugin outputs Nagios-compatible status messages and
exit codes to integrate cleanly with existing monitoring.

## Available checks

| Script | Purpose |
| --- | --- |
| `flexlm_diag_expiry.sh` | Reports upcoming licence expirations parsed from `lmutil lmstat` output. |
| `flexlm_diag_status.sh` | Monitors FLEXlm server availability and raises UNKNOWN for ambiguous diagnostics. |
| `rlm_diag_status.sh` | Monitors RLM server availability while validating command dependencies. |

## Usage

All scripts are POSIX shell and require the corresponding vendor utilities to be
available on `PATH` (for example `lmutil` for FLEXlm or `rlmutil` for RLM). Run
the desired script with `-h` to see its argument requirements and usage
examples. Each script validates its inputs and returns one of the standard
Nagios exit codes:

* `0` (OK)
* `1` (WARNING)
* `2` (CRITICAL)
* `3` (UNKNOWN)

## Development

These scripts are linted with `shellcheck`. Run the linter locally with:

```sh
shellcheck flexlm_diag_expiry.sh flexlm_diag_status.sh rlm_diag_status.sh
```

(If `shellcheck` is not installed the command will exit with a not found error.)
