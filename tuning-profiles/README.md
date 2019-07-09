# Satellite Tuning Profiles

Tuning settings for Satellite 6 with 32, 64, 128G and 256G of RAM. If you have less than 32G RAM the default settings for Satellite 6 are appropriate.

**NOTE: These tuning files can be applied to Satellite 6.4 and later.**

Instructions for use:

1) Backup your previous /etc/foreman-installer/custom-hiera.yaml to custom-hiera.original

2) Copy file that matches RAM on your Satellite to /etc/foreman-installer/custom-hiera.yaml

3) If you had settings previously added in custom-hiera.original that do not exist in the copied custom-hiera.yaml, you may need to re-add them to the copied file. Take care to preserve values added by the upgrade process such as:

```
# Added by foreman-installer during upgrade, run the installer with --upgrade-mongo-storage to upgrade to WiredTiger.
mongodb::server::storage_engine: 'mmapv1'
```

4) run 'satellite-installer' with no arguments to apply these settings
