postgresql_ha
=============

An Ansible role to configure PostgreSQL High Availability (HA) on AlmaLinux 9 systems using **Repmgr** for PostgreSQL replication and failover management, and **Keepalived** for virtual IP (VIP) management.

This role complements an existing PostgreSQL installation by adding high availability through replication, automatic failover, and a shared VIP.

Requirements
------------

- AlmaLinux 9 or compatible distribution
- PostgreSQL already installed and configured (e.g., via a separate role)
- SSH key-based authentication configured between all PostgreSQL nodes
- Proper firewall configuration allowing:
  - PostgreSQL ports (`5432`)
  - Repmgr ports (default `5432`, can vary)
  - Keepalived/VRRP protocol (protocol number `112`)
- Proper `pg_hba.conf` configuration to allow replication and repmgr connections. A minimal example snippet:
  ```
  # Allow replication connections from all nodes
  host    replication     repmgr          192.168.34.0/24          md5
  # Allow repmgr user connections for monitoring and management
  host    all             repmgr          192.168.34.0/24          md5
  ```

Role Variables
--------------

The following variables are configurable:

| Variable | Default | Description |
|----------|---------|-------------|
| `postgresql_version` | `"14.18"` | Full PostgreSQL version |
| `postgresql_version_major` | `"{{ postgresql_version \| split('.') \| first }}"` | Major version number |
| `postgresql_daemon` | `"postgresql-{{ postgresql_version_major }}"` | PostgreSQL systemd service name |
| `postgresql_repmgr_host` | `"{{ ansible_facts['default_ipv4']['address'] }}"` | Local node IP for repmgr |
| `postgresql_repmgr_node_id` | `1` | Unique integer node ID |
| `postgresql_data_dir` | `"/var/lib/pgsql/{{ postgresql_version_major }}/data"` | PostgreSQL data directory |
| `postgresql_bin_path` | `"/usr/pgsql-{{ postgresql_version_major }}/bin"` | PostgreSQL binaries path |
| `postgresql_config_path` | `"/var/lib/pgsql/{{ postgresql_version_major }}/data"` | PostgreSQL configuration directory |
| `postgresql_ha_vip_cidr` | `192.168.34.100/24` | VIP with CIDR notation for HA |
| `postgresql_ha_vip_if` | `eth0` | Interface for the VIP |
| `postgresql_ha_hosts` | `["192.168.34.11", "192.168.34.12"]` | List of cluster node IPs |
| `postgresql_repmgr_peer` | `{{ postgresql_ha_hosts \| difference(postgresql_repmgr_host) \| first }}` | Peer node address |
| `postgresql_ha_initial_role` | `"primary"` | Initial role: `primary` or `standby` |
| `postgresql_repmgr_password` | `"repmgrpa"` | Password for the `repmgr` user |
| `postgresql_ha_post_primary_scripts` | `[]` | Optional list of commands executed by `follow.sh` after a node remains/becomes primary |
| `postgresql_ha_post_standby_scripts` | `[]` | Optional list of commands executed by `follow.sh` after standby follow/rejoin |

Features
--------

This role includes several tools and configurations to ensure smooth PostgreSQL HA operation:

- **Health check script `check_postgres.sh`**: Verifies primary write availability and standby replication status to ensure cluster health.
- **Follow script `follow.sh`**: Handles automatic rejoin and rewind operations after failover events.
- **Custom post-role hooks**: `follow.sh` can run additional commands when a node becomes primary or standby (controlled via `postgresql_ha_post_*_scripts`).
- **`repmgrd` and `keepalived` managed via systemd**: Both services are configured with autorestart to maintain availability.
- **Automatic SSH key exchange**: Sets up SSH key-based authentication for the `postgres` user between all cluster nodes to enable seamless communication.
- **Aliases for common cluster operations**: Installs convenient aliases such as `cluster show`, `switchover`, and `logs` for easier management.
- **SELinux set to permissive mode (boot persistent)**: Ensures compatibility with repmgr and keepalived without security policy conflicts.

Operational Notes
-----------------

This role installs several aliases to simplify cluster management. The following table lists the available HA aliases:

| Command         | Description                                                       |
|-----------------|-------------------------------------------------------------------|
| `ha-show`       | Show cluster status                                               |
| `ha-role`       | Show current node role (PRIMARY or STANDBY)                       |
| `ha-timeline`   | Show current timeline ID                                          |
| `ha-switch`     | Controlled switchover (run on standby)                            |
| `ha-pause`      | Pause repmgrd automation                                          |
| `ha-unpause`    | Unpause repmgrd automation                                        |
| `ha-paused`     | Show status of repmgrd automation                                 |
| `ha-status`     | Show systemd status of PostgreSQL, repmgrd, keepalived            |
| `ha-restart`    | Restart PostgreSQL, repmgrd, keepalived                           |
| `ha-logs`       | Tail logs from PostgreSQL, repmgrd, keepalived, follow/check scripts |
| `ha-vip`        | Show current VIP assignment on local node                         |
| `ha-vip-arp`    | Show ARP neighbors for VIP                                        |
| `ha-check`      | Run local health check script                                     |
| `ha-alias-help` | Show all HA aliases with their descriptions                       |

Custom Hooks
------------

You can provide additional commands to execute when a node transitions into or remains in a specific role by populating `postgresql_ha_post_primary_scripts` or `postgresql_ha_post_standby_scripts`. Each entry should be a full command string (for example `/usr/local/bin/seq_resync.sh`). The commands are invoked by `/usr/local/bin/follow.sh` via `bash -lc` so they inherit the shell environment available to the script.

Dependencies
------------

- None directly. Assumes PostgreSQL is managed by another existing Ansible role.

Example Playbook
----------------

A basic example showing how to set up PostgreSQL HA using this role:

```yaml
- hosts: postgres_cluster
  vars:
    postgresql_repmgr_node_id: "{{ ansible_hostname[-2:] | int }}"
    postgresql_ha_vip_cidr: "10.0.0.200/24"
    postgresql_ha_vip_if: "ens192"
    postgresql_ha_hosts:
      - "10.0.0.101"
      - "10.0.0.102"
    postgresql_repmgr_password: "your-strong-password"

  roles:
    - role: ahu_services.postgresql_ha
```
