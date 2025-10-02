# FLEXlm / RLM Nagios Checks

This repository provides a small collection of Bash scripts intended to be used
as Nagios plugins for monitoring FLEXlm and RLM license servers. The scripts
wrap the vendor utilities (`lmutil` and `rlmutil`) and surface their results in
standard Nagios return codes.

## Checks

### `flexlm_diag_status.sh`
Validates that a given FLEXlm feature can be checked out.

```bash
./flexlm_diag_status.sh [-l /path/to/lmutil] <port> <server> <feature>
```

* Returns `OK` when the feature can be checked out.
* Returns `CRITICAL` when checkout is reported as impossible or the feature does
  not exist.
* Returns `UNKNOWN` if the diagnostic command fails or produces unexpected
  output.

### `flexlm_diag_expiry.sh`
Reports the furthest license expiry for a FLEXlm feature and compares it to an
alert window.

```bash
./flexlm_diag_expiry.sh [-l /path/to/lmutil] <port> <server> <feature> <alert_days>
```

* Returns `OK` when the furthest expiry is at least `<alert_days>` in the future.
* Returns `CRITICAL` when the furthest expiry is sooner than `<alert_days>`.
* Returns `UNKNOWN` when no expiry dates can be parsed or when the diagnostic
  command fails.

### `rlm_diag_status.sh`
Checks that an RLM server is reporting an "on" status for the provided ISV
module.

```bash
./rlm_diag_status.sh [-r /path/to/rlmutil] <port> <server> <isv>
```

* Returns `OK` when the server status string is detected.
* Returns `CRITICAL` when an explicit failure string is present.
* Returns `WARNING` when the server is up but reporting no licenses in use.
* Returns `UNKNOWN` if the utility cannot be executed or the output is
  unexpected.

## Configuration

Each script honours an environment variable that lets you override the default
utility paths:

* `LMUTIL_PATH` for the FLEXlm checks.
* `RLMUTIL_PATH` for the RLM check.

You can also override the path on the command line with `-l`/`-r`.

## Exit Codes

All scripts follow Nagios exit code semantics:

* `0` – OK
* `1` – WARNING
* `2` – CRITICAL
* `3` – UNKNOWN
