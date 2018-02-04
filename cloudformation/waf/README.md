# ALB WAF Rules

## About
The CloudFormation templates in this directory, will handle initial seeding of the WAF rules for the Application Load Balancer.

Eventually we will want to add all of these directly into Terraform.

## Details

This CloudFormation template sourced from: https://s3.amazonaws.com/solutions-reference/aws-waf-security-automations/latest/aws-waf-security-automations.pdf will create several canned WAF Rules for use with an ALB.

## Running

Run [./bin/manage-cf-waf-stack.sh](../../bin/manage-cf-waf-stack.sh) to create the WAF Stack, then run_terraform to associate the ALBs with the rules. Additional Rules should be created within terraform itself.

```bash
./bin/manage-cf-waf-stack.sh
Usage: manage-cf-waf-stack.sh <command>

Available commands are:
create        Creates the stack for use.
associate     Associates the WebACL with the ALBs created by terraform.
```

### Create

To create the stack, which only needs to happen once per account, run the `create` command.

```bash
./bin/manage-cf-waf-stack.sh create
```

### Associate

After `terraform` has created the ALBs for the web applications, you can then associate
the WebACLs created with this tool to the `terraform` created ALBs.

```bash
./bin/manage-cf-waf-stack.sh associate
```
