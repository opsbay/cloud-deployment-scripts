resource "aws_iam_role" "alertlogic-role" {
  name = "tf-alertlogic-${substr(var.aws-environment, 16, -1)}-role"

  # References:
  #     http://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-sharing-logs-third-party.html
  #     http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html
  #     https://docs.alertlogic.com/gsg/amazon-web-services-cloud-defender-cross-account-role-config.htm
  #     https://docs.alertlogic.com/pdf-files/defender-single_account-full.txt
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::733251395267:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "26353"
      }
    }
  }
}
POLICY
}

resource "aws_iam_role_policy" "alertlogic-role-policy" {
  depends_on = ["aws_iam_role.alertlogic-role"]

  name = "tf-alertlogic-${substr(var.aws-environment, 16, -1)}-role-policy"
  role = "tf-alertlogic-${substr(var.aws-environment, 16, -1)}-role"

  # Note: The policy document is always updated and published under the ? icon in Alertlogic web interface
  # References:
  #     https://docs.alertlogic.com/gsg/amazon-web-services-cloud-defender-cross-account-role-config.htm
  #     https://docs.alertlogic.com/pdf-files/defender-single_account-full.txt
  policy = <<POLICY
{
    "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "EnabledDiscoveryOfVariousAWSServices",
                "Effect": "Allow",
                "Action": [
                    "autoscaling:Describe*",
                    "directconnect:Describe*",
                    "elasticloadbalancing:Describe*",
                    "ec2:Describe*",
                    "rds:Describe*",
                    "rds:DownloadDBLogFilePortion",
                    "rds:ListTagsForResource"
                ],
                "Resource": "*"
            },
            {
                "Sid": "EnableMinimalS3AccessToplevel",
                "Effect": "Allow",
                "Action": [
                    "s3:ListAllMyBuckets",
                    "s3:GetBucketLocation"
                ],
                "Resource": "*"
            },
            {
                "Sid": "EnableMinimalS3Access",
                "Effect": "Allow",
                "Action": [
                    "s3:ListBucket",
                    "s3:GetObject",
                    "s3:GetBucket*",
                    "s3:GetObjectAcl",
                    "s3:GetObjectVersionAcl"
                ],
                "Resource": "arn:aws:s3:::outcomesbucket-*"
            },
            {
                "Sid": "EnableCloudTrailIfAccountDoesntHaveCloudTrailsEnabled",
                "Effect": "Allow",
                "Action": [
                    "cloudtrail:*"
                ],
                "Resource": "*"
            },
            {
                "Sid": "CreateCloudTrailS3BucketIfCloudTrailsAreBeingSetupByAlertLogic",
                "Effect": "Allow",
                "Action": [
                    "s3:CreateBucket",
                    "s3:PutBucketPolicy",
                    "s3:DeleteBucket"
                ],
                "Resource": "arn:aws:s3:::outcomesbucket-*"
            },
            {
                "Sid": "CreateCloudTrailsTopicTfOneWasntAlreadySetupForCloudTrails",
                "Effect": "Allow",
                "Action": [
                    "sns:CreateTopic",
                    "sns:DeleteTopic"
                ],
                "Resource": "arn:aws:sns:*:*:outcomestopic"
            },
            {
                "Sid": "MakeSureThatCloudTrailsSnsTopicIsSetupCorrectlyForCloudTrailPublishingAndSqsSubsription",
                "Effect": "Allow",
                "Action": [
                    "sns:addpermission",
                    "sns:gettopicattributes",
                    "sns:listtopics",
                    "sns:settopicattributes",
                    "sns:subscribe"
                ],
                "Resource": "arn:aws:sns:*:*:outcomestopic"
            },
            {
                "Sid": "BeAbleToValidateOurRoleAndDiscoverIAM",
                "Effect": "Allow",
                "Action": [
                    "iam:List*",
                    "iam:Get*"
                ],
                "Resource": "*"
            },
            {
                "Sid": "CreateAlertLogicSqsQueueToSubscribeToCloudTrailsSnsTopicNotifications",
                "Effect": "Allow",
                "Action": [
                    "sqs:CreateQueue",
                    "sqs:DeleteQueue",
                    "sqs:SetQueueAttributes",
                    "sqs:GetQueueAttributes",
                    "sqs:ListQueues",
                    "sqs:ReceiveMessage",
                    "sqs:DeleteMessage",
                    "sqs:GetQueueUrl"
                ],
                "Resource": "arn:aws:sqs:*:*:outcomesbucket*"
            }
        ]
}
POLICY
}
