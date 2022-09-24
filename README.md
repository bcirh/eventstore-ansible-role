Ansible Role: Eventstore
=========

This is Ansible role provides automatic configuration of [EventStore](https://www.eventstore.com/).

**This is work in progress and it's only for learning.**
**Please don't use this role in production environment.**

Requirements
------------

No special requirements; note that this role requires root access

Role Variables
--------------

| Name | Value | Description |
|---|---|---|
| insecure | Default = false | When `false` installs Eventstore with certificates |
| eventstore_version | Default = "21.10.5" | Eventstore version |
| int_tcp_port | Default = 1112  | Eventstore internal tcp port |
| ext_tcp_port | Default = 1113  | Eventstore external tcp port  |
| enable_external_tcp | Default = false | Enable external connection on tcp protocol |
| enable_atom_pub_over_http | Default = true | Enable AtomPub |
| run_projections | Default = All | RunProjections Level *values:* `All` `System` `None` |
| cluster_size | Default = 3 | Number of Eventstore nodes |
| read_only_replica | Default = None | Set read only replica |
| no_of_open_files | Default = 32768 | Number of open files allowed on linux host. |
| eventstore_cluster_dns | Default = None | Use dns server discovery. |
| cron_scavange_day | Default = None **(Acceptable values are 0-6)** | Set the scavange day for cron job. If this variable is not defined value for day will be random |
| int_tcp_heartbeat_interval | Default = None | Eventstore heartbeat interval **Note:** When variable is not defined Event Store default value will be used |
| int_tcp_heartbeat_timeout | Default = None | Eventstore heartbeat timeout **Note:** When variable is not defined Event Store default value will be used |
| commit_timeout_ms | Default = None | Eventstore commit timeout **Note:** When variable is not defined EventStore default value will be used |

Example Playbook
----------------

```
- name: Install eventstore playbook
  hosts: 
    - es_cluster
    - read_only
  roles:
    - eventstore
    
```
Example Inventory
-----------------
```
[es_cluster]
xxx.xxx.xxx.xxx ansible_user=test cron_scavange_day=0
xxx.xxx.xxx.xxx ansible_user=test #cron_scavange_day=1
xxx.xxx.xxx.xxx ansible_user=test cron_scavange_day=2

[read_only]
xxx.xxx.xxx.xxx ansible_user=test cron_scavange_day=3

[all:vars]
eventstore_version = "21.10.5"
insecure=false
es_user=admin
es_password=changeit
eventstore_cluster_dns=eventstore.cluster.example.dns

[read_only:vars]
read_only_replica=true

```
* Run `export ANSIBLE_HOST_KEY_CHECKING=False`
* Run `ansible-playbook -i inventory setup_es.yml`

License
-------

MIT

Author Information
------------------

bcirh
