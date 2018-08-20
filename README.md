# My python-dummy for testing integrations into TSI Cloud Portal

based on [the generic server Portal app](https://github.com/EMBL-EBI-TSI/cpa-instance.git)

## deployment with docker:
mwalzer/cloudconnect
```
docker run -it -v /<...>/portal-dummy/:/data/:ro -v /<...>/ext6-openrc_v2.sh:/cred/ext.sh:ro -v /<...>/s3-credentials.sh:/cred/s3.sh:ro  -v /home/<user>/.ssh:/home/user/.ssh:ro -v /<...>/portal-dummy/deployments:/root/app/deployments:rw mwalzer/cloudconnect
source /cred/ext.sh
source /cred/s3.sh
cp -r /data/* ~/app
cd ~/app
source up.sh
```
where `s3-credentials.sh` should be something like:
```
#!/usr/bin/env bash
export S3_ID="???"
export S3_KEY="???"
export S3_BUCKET="???"
``` 
and `ext6-openrc_v2.sh` the tenancy environment variables.
The `.ssh` folder is expected to contain `id_rsa.pub` and `id_rsa` key files.

The tenancy has to hold an image named "Ubuntu16.04",  and enough Volume Storage for an at least rudimentary glusterFS.

See `up.sh` for the variables set (as it would be expected in the portal's deployment parameters)

## issues fixed:
* PPA in GlusterFS yml (version 3.10 still works - nothing above nor below that :/ )
* default params in weave
https://github.com/kubernetes-incubator/kubespray/issues/2021
* galaxy image generic build from version 17.09
