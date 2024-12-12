Role Name
=========

[Promtail](https://www.influxdata.com/time-series-platform/telegraf/) is an agent which ships the contents of local logs to a private Grafana Loki instance or Grafana Cloud. It is usually deployed to every machine that runs applications which need to be monitored.

This feeds a Loki Log Collector.  Others too, but I am not ready to test others.  It is likely going to dies a slow death as [Grafana Alloy](https://grafana.com/docs/loki/latest/send-data/alloy/) takes over.

This installs a systemd daemon. It can be cleaned up, but that is not very well tested or kept up.

Requirements
------------

Handled by package install.

Role Variables
--------------

By default this role installs. There are the state variable is 'present' or 'absent'.  See the playbook for how to use.

There are two varables used to communicate with the server.  Look at the inventory.yml for my configuration.

```
telegraf_influxdb_url: "monitor.local"
telegraf_influxdb_token: "its a secret==" 
telegraf_state: present
```


Dependencies
------------

none

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

 ```
- name: Telegraf Removal
  hosts: localhost
  connection: local

  vars:
    telegraf_state: absent

  roles:
    - telegraf
 ```

License
-------

MIT

Author Information
------------------

Jack Lavender, et al.