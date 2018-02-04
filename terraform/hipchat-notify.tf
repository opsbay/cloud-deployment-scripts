resource "aws_iam_role" "tf-hipchat-notify-role" {
  name = "tf-hipchat-notify-${var.environments[count.index]}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Action": "sts:AssumeRole",
    "Principal": {
    "Service": "lambda.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
  }
  ]
}
EOF

  count = "${length(var.environments)}"
}

resource "aws_iam_role_policy" "hipchat-notify-role-policy" {
  name = "tf-hipchat-notify-${var.environments[count.index]}-role-policy"
  role = "${element(aws_iam_role.tf-hipchat-notify-role.*.name, count.index)}"

  lifecycle {
    create_before_destroy = true
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF

  count = "${length(var.environments)}"
}

data "template_file" "config" {
  template = "${file("../bin/lambda/notify-hipchat/config.tpl.js")}"

  vars {
    hipchat_cloudwatch_topic_arn = "${element(aws_sns_topic.hipchat_cloudwatch_sns.*.arn, count.index)}"
    hipchat_codedeploy_topic_arn = "${element(aws_sns_topic.hipchat_codedeploy_sns.*.arn, count.index)}"
  }

  count = "${length(var.environments)}"
}

data "archive_file" "notify_function" {
  type        = "zip"
  output_path = "tf-plan-dep-notify-hipchat-${var.environments[count.index]}.zip"

  source {
    content  = "${file("../bin/lambda/notify-hipchat/index.js")}"
    filename = "index.js"
  }

  source {
    content  = "${element(data.template_file.config.*.rendered, count.index)}"
    filename = "config.js"
  }

  count = "${length(var.environments)}"
}

resource "aws_lambda_function" "notify_hipchat" {
  function_name    = "tf-notify-hipchat-${var.environments[count.index]}"
  handler          = "index.handler"
  runtime          = "nodejs6.10"
  filename         = "${element(data.archive_file.notify_function.*.output_path, count.index)}"
  source_code_hash = "${element(data.archive_file.notify_function.*.output_base64sha256, count.index)}"
  role             = "${element(aws_iam_role.tf-hipchat-notify-role.*.arn, count.index)}"

  count = "${length(var.environments)}"
}

resource "aws_sns_topic" "hipchat_cloudwatch_sns" {
  name = "tf-hipchat-cloudwatch-notifications-${var.environments[count.index]}-topic"

  count = "${length(var.environments)}"
}

resource "aws_sns_topic_subscription" "hipchat_cloudwatch_sns_subscription" {
  topic_arn = "${element(aws_sns_topic.hipchat_cloudwatch_sns.*.arn, count.index)}"
  protocol  = "lambda"
  endpoint  = "${element(aws_lambda_function.notify_hipchat.*.arn, count.index)}"

  count = "${length(var.environments)}"
}

resource "aws_lambda_permission" "hipchat_cloudwatch_lambda_permission" {
  statement_id  = "tf-execute-lambda-cloudwatch"
  action        = "lambda:InvokeFunction"
  function_name = "${element(aws_lambda_function.notify_hipchat.*.arn, count.index)}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${element(aws_sns_topic.hipchat_cloudwatch_sns.*.arn, count.index)}"

  count = "${length(var.environments)}"
}

resource "aws_sns_topic" "hipchat_codedeploy_sns" {
  name = "tf-hipchat-codedeploy-notifications-${var.environments[count.index]}-topic"

  count = "${length(var.environments)}"
}

resource "aws_sns_topic_subscription" "hipchat_codedeploy_sns_subscription" {
  topic_arn = "${element(aws_sns_topic.hipchat_codedeploy_sns.*.arn, count.index)}"
  protocol  = "lambda"
  endpoint  = "${element(aws_lambda_function.notify_hipchat.*.arn, count.index)}"

  count = "${length(var.environments)}"
}

resource "aws_lambda_permission" "hipchat_codedeploy_lambda_permission" {
  statement_id  = "tf-execute-lambda-codedeploy"
  action        = "lambda:InvokeFunction"
  function_name = "${element(aws_lambda_function.notify_hipchat.*.arn, count.index)}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${element(aws_sns_topic.hipchat_codedeploy_sns.*.arn, count.index)}"

  count = "${length(var.environments)}"
}
