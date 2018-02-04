# configs.sh

This script will allow a user to `pull` or `push` application configs from an S3 bucket, for editing.
You can `pull` down a set of configs, then edit it and `push` it back up, to S3.
The configs are stored in the bucket `s3://unmanaged-app-config-${AWS_ACCOUNT_ID}/configs/${environment}/${application}/`, so, by specifying the environment and application name (succeed, succeed-legacy and naviance-node), you can choose what files you want to deal with.

The following command would pull the dev configs of succeed to /tmp/foo:
```
    ./configs.sh pull dev succeed /tmp/foo
```

You could then edit the configs and then push them from /tmp/foo to the S3 bucket with:
```
    ./configs.sh push dev succeed /tmp/foo
```

We also have skeleton configs in codedeploy/configs/templates.
You can use those templates to generate a set of configs based on environment and application name.
For example:
```
    ./configs.sh init dev succeed ~/myconfigs/succeed /path/to/succeed.dev.env
```
That would replace the values in your templates with the values set in /path/to/succeed.dev.env and generate those files to the ~/myconfigs/succeed directory.

The contents of succeed.dev.env might look like:
```
__FC_SERVER_NAME__='connection.local.naviance.com'
__CLIENT_PATH__='/clients/'
__NAV_ENV__='dev'
```