variable "name" {
  description = "Name of the lambda stack"
}

variable "description" {
  description = "Description of what your Lambda Function does. This would appear in the AWS Lambda list"
  default     = ""
}

variable "aws-account-env" {}

# This requires a data resource, each lambda fn requires different permissions
variable "lambda_iam_policy_document" {
  # http://docs.aws.amazon.com/lambda/latest/dg/intro-permission-model.html#lambda-intro-execution-role
  description = "Policy document for the lambda's role"
}

variable "filename" {
  description = "The path to the function's deployment package within the local filesystem"
}

variable "runtime" {
  description = "The runtime environment for the Lambda function"

  # https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#SSS-CreateFunction-request-Runtime
  # http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html#options
}

variable "handler" {
  description = "The function entrypoint in the code"
}

variable "source_code_hash" {
  description = "Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename"
}

variable "timeout" {
  description = "Amount of time the lambda function has to run in seconds"

  # https://docs.aws.amazon.com/lambda/latest/dg/limits.html

  default = 3
}

variable "permission_principal" {
  description = "The principal who is getting the permission to invoke lambda"

  # https://www.terraform.io/docs/providers/aws/r/lambda_permission.html#principal
}

variable "permission_source_arn" {
  description = "Only events generated from the specified Amazon Resource Name (ARN) can invoke lambda"
}
