# Linux Process Sentinel

A bash-based service watchdog that monitors a target systemd service, automatically restarts it on failure, and logs every recovery event with timestamps and a running restart counter.

Built as a Linux portfolio project covering the processes and services domain, systemd unit authoring, programmatic health checks, structured event logging, and the difference between systemd's built-in `Restart=` directive and an external watchdog.

---

## What It Does

The sentinel polls a target service every 10 seconds using `systemctl is-active`. If the service is down, the sentinel restarts it, waits 3 seconds, confirms recovery, and logs the result. Every event — alert, recovery, or failure to recover is written to both a structured log file and the system journal via `logger`.

```
[2026-05-09 08:39:21] [ALERT] dummy-app is inactive. Restarting... (restart #1)
[2026-05-09 08:39:24] [OK] dummy-app is back up after restart #1
[2026-05-09 08:39:34] [OK] dummy-app is active.
```

---

## Architecture

```
sentinel.service (Restart=always)
    └── sentinel.sh
            └── polls dummy-app every 10s via systemctl is-active
                    ├── active → log [OK], continue
                    └── inactive → log [ALERT] → systemctl start dummy-app
                                       ├── recovered → log [OK]
                                       └── still down → log [FAILED]

dummy-app.service (Restart=no)
    └── dummy-app.sh
            └── heartbeat loop — prints timestamp every 5s to journal
```

**Why `Restart=no` on the target?**
The sentinel owns recovery. If systemd auto-restarted the target too, there would be no way to prove the watchdog actually did anything. The target is deliberately left without a restart policy so the sentinel's intervention is visible and measurable.

**Why `Restart=always` on the sentinel?**
The watchdog itself should never stay dead. If the sentinel crashes for any reason, systemd brings it back so monitoring is always running.

---

## Project Files

| File | Purpose |
|---|---|
| `sentinel.sh` | The watchdog script — polls, detects, restarts, logs |
| `dummy-app.sh` | Simulated target service — heartbeat loop |
| `sentinel.service` | systemd unit for the sentinel (Restart=always) |
| `dummy-app.service` | systemd unit for the target (Restart=no) |

---

## Setup

### 1. Deploy the scripts

```bash
sudo cp dummy-app.sh /usr/local/bin/dummy-app.sh
sudo cp sentinel.sh /usr/local/bin/sentinel.sh
sudo chmod +x /usr/local/bin/dummy-app.sh
sudo chmod +x /usr/local/bin/sentinel.sh
```

### 2. Install the systemd units

```bash
sudo cp dummy-app.service /etc/systemd/system/dummy-app.service
sudo cp sentinel.service /etc/systemd/system/sentinel.service
sudo systemctl daemon-reload
```

### 3. Enable and start both services

```bash
sudo systemctl enable --now dummy-app
sudo systemctl enable --now sentinel
```

### 4. Confirm both are running

```bash
systemctl status dummy-app
systemctl status sentinel
```

---

## Testing the Watchdog

Kill the target and watch the sentinel respond:

```bash
# Terminal 1 — follow the sentinel journal
journalctl -u sentinel -f

# Terminal 2 — kill the target
sudo systemctl stop dummy-app
```

Within 10 seconds you'll see the ALERT fire, the restart execute, and the RECOVERY confirm — all in the journal.

Recovery events are also written to `~/sentinel-logs/sentinel.log`.

---

## Key Concepts Demonstrated

**`systemctl is-active`** — Returns the string `active` or `inactive`. Used here as a programmatic health check rather than a human-readable status display.

**`logger -t sentinel`** — Writes directly to the system journal from a bash script. The `-t` flag sets the syslog identifier so events are filterable with `journalctl -t sentinel`.

**systemd `Restart=` directive** — Controls what systemd does when a service exits. `Restart=always` restarts regardless of exit code. `Restart=no` means systemd never intervenes — used deliberately on the target so the sentinel owns recovery.

**`daemon-reload`** — Required after any unit file change. systemd caches unit files in memory; without a reload, edits are ignored.

---

## Challenges Encountered

**Intentional `Restart=no` design decision**
The instinct when building this was to set `Restart=on-failure` on the dummy app. Leaving it as `no` feels wrong until you think it through — but that's the whole point. The sentinel has to be the only thing doing the restarting, or you can't measure whether it's working. Separating responsibilities cleanly matters even in a small project.

**`logger` vs. file logging**
Used both intentionally. The `~/sentinel-logs/sentinel.log` file gives a portable, human-readable record that travels with the project. The `logger` calls write to the system journal, making the sentinel's events queryable alongside all other system events — which is how real monitoring integrates with a host.

---

## What's Next

- Add configurable alert thresholds (e.g. send a notification after N restarts)
- Extend to watch multiple services in parallel
- Integrate with a real notification channel (email, Slack webhook)
- Replace the dummy app with a real service (nginx, a Python app, etc.)

---

## Related Projects

- [linux-sys-audit](https://github.com/mattrshaw4/linux-sys-audit) — Four-domain system health audit script with systemd timer automation
