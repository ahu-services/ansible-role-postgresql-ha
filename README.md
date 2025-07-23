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

Role Variables
--------------

The following variables are configurable:

| Variable                    | Default                  | Description                                                  |
|-----------------------------|--------------------------|--------------------------------------------------------------|
| `postgresql_ha_vip`         | `192.168.1.100`          | Virtual IP (VIP) address shared by the PostgreSQL cluster.   |
| `postgresql_ha_interface`   | `eth0`                   | Network interface for the VIP                                |
| `postgresql_ha_router_id`   | `51`                     | VRRP router ID used by Keepalived                            |
| `postgresql_ha_priority`    | Primary: `100`, Standby: `90` | Priority of Keepalived (Master has higher priority)          |
| `postgresql_ha_auth_pass`   | `securepass`             | Authentication password for VRRP                             |
| `postgresql_ha_nodes`       | see defaults             | List of nodes participating in HA                            |
| `postgresql_ha_initial_primary` | `false`              | Set to `true` for initial Primary server, otherwise `false`  |

Dependencies
------------

- None directly. Assumes PostgreSQL is managed by another existing Ansible role.

Example Playbook
----------------

A basic example showing how to set up PostgreSQL HA using this role:

```yaml
- hosts: postgres_cluster
  vars:
    postgresql_ha_vip: "10.0.0.200"
    postgresql_ha_interface: "ens192"
    postgresql_ha_auth_pass: "your-strong-password"
    postgresql_ha_nodes:
      - { hostname: "pg-node1", ip: "10.0.0.101", primary: true }
      - { hostname: "pg-node2", ip: "10.0.0.102", primary: false }

  roles:
    - role: your_namespace.postgresql_ha
