# Terraform

This directory contains the scripts and files to setup a testapp stack on AWS with:
 - Elastic Load Balancer
 - AutoScaling Groups
 - CodeDeploy Deployment Groups

Once this stack is running, you can deploy/rollback versions of testapp through CodeDeploy.

It is a good idea to run `terraform fmt` before committing a change.

## CodeDeploy

You can use the AWS Console to deploy the included test application 
```
AWS_ACCOUNT_ID=$(aws ec2 describe-security-groups --query 'SecurityGroups[0].OwnerId' --output text)
aws deploy create-deployment --application-name tf-testapp --s3-location bucket=tf-codedeploy-${AWS_ACCOUNT_ID},key=testapp-placeholder-01.zip,bundleType=zip --deployment-group-name testing
```
