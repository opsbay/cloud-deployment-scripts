# Single lambda by AWS account.
# Note: If we want general lambda functions per environment, we'll need a new
#       module.
###############################################################################

resource "aws_iam_role" "tf-lambda-role" {
  name = "tf-lambda-${var.name}-${var.aws-account-env}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "tf-lambda-role-policy" {
  depends_on = ["aws_iam_role.tf-lambda-role"]

  name = "tf-lambda-${var.name}-${var.aws-account-env}-role-policy"
  role = "tf-lambda-${var.name}-${var.aws-account-env}-role"

  # This requires a data resource, each lambda requires different permissions
  policy = "${var.lambda_iam_policy_document}"
}

resource "aws_lambda_function" "tf-lambda-function" {
  function_name    = "tf-lambda-${var.name}-${var.aws-account-env}-function"
  filename         = "${var.filename}"
  role             = "${aws_iam_role.tf-lambda-role.arn}"
  runtime          = "${var.runtime}"
  handler          = "${var.handler}"
  source_code_hash = "${var.source_code_hash}"
  description      = "${var.description}"

  # https://docs.aws.amazon.com/lambda/latest/dg/limits.html
  timeout = "${var.timeout}"
}

resource "aws_lambda_permission" "tf-lambda-permission" {
  statement_id = "tf-lambda-${var.name}-${var.aws-account-env}-permission"

  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.tf-lambda-function.arn}"

  # The principal who is getting this permission
  # https://www.terraform.io/docs/providers/aws/r/lambda_permission.html#principal
  principal = "${var.permission_principal}"

  source_arn = "${var.permission_source_arn}"
}
