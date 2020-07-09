# Restart Dynflow Executors

A rake script to restart Dynflow executors when memory limit exceeded and no extensive tasks are running.

Instructions for use:

1) Download the script to Satellite's "/usr/share/foreman/lib/tasks/" directory.

2) Copy "restart-dynflow.cron" file to "/etc/cron.d" directory.

3) Adjust the cron job schedule and memory limit as needed.

4) You can run the script manually.

```
foreman-rake foreman_tasks:restart_dynflow

# Run with custom memory limit. The default is 1.5GB
MEMORY_LIMIT_GB=2 foreman-rake foreman_tasks:restart_dynflow
```
