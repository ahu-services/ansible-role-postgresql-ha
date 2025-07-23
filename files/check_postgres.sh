#!/bin/bash
set -euo pipefail

user='repmgr'
database='repmgr'

# Console output control: enabled if stdout is a TTY, or via flag (-v/--console/--verbose), or env PG_CHECK_CONSOLE=1
console=0
if [ -t 1 ]; then console=1; fi
for arg in "$@"; do
  case "$arg" in
    -v|--console|--verbose)
      console=1
      ;;
  esac
done
if [ "${PG_CHECK_CONSOLE:-0}" = "1" ]; then console=1; fi

log(){
  /usr/bin/logger -t pg_check -- "$1"
  if [ "$console" = "1" ]; then
    printf '%s - %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$1"
  fi
}

log "Checking PostgreSQL status..."

# Standby check (local)
is_standby=$(/usr/bin/psql -U "$user" -d "$database" -tAc "SELECT pg_is_in_recovery()" 2>/dev/null || echo "")
if [ -z "$is_standby" ]; then
  log "Error checking recovery mode."
  exit 1
fi

if [ "$is_standby" = "t" ]; then
  # VIP-strict: never succeed on standby
  log "Node is standby. Returning failure to keep VIP off this node."
  exit 1
else
  log "Node is primary. Verifying writability (read_only should be off, temp write works)."

  # Quick readonly check
  read_only=$(/usr/bin/psql -U "$user" -d "$database" -tAc "SHOW default_transaction_read_only" 2>/dev/null || echo "")
  if [ -z "$read_only" ]; then
    log "Failed to read default_transaction_read_only."
    exit 1
  fi
  if [ "$read_only" != "off" ]; then
    log "Instance reports read-only mode ($read_only)."
    exit 1
  fi

  # Lightweight write probe using TEMP table (lives in session only)
  if ! /usr/bin/psql -U "$user" -d "$database" -v ON_ERROR_STOP=1 -q <<'SQL'
BEGIN;
CREATE TEMP TABLE _vip_check(x int);
INSERT INTO _vip_check VALUES (1);
DROP TABLE _vip_check;
COMMIT;
SQL
  then
    log "Writable check via TEMP table failed."
    exit 1
  fi

  log "Primary is writable. PostgreSQL is working properly."
  exit 0
fi
