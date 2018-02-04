resource "aws_iam_role_policy" "cloudtrail_policy" {
  name = "tf-cloudtrail-logs-s3-readonly-access"
  role = "${aws_iam_role.cloudtrail_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": [
        "arn:aws:s3:::unmanaged-cloudtrail-${var.aws-account-id}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "cloudtrail_role" {
  name = "tf_CloudTrail_CloudWatchLogs_Role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codedeploy.amazonaws.com",
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
