resource "aws_sqs_queue" "district_imports_queue" {
  name = "tf-district-imports-${var.environments[count.index]}"

  count = "${length(var.environments)}"
}

data "template_file" "district_imports_queue_policy_template" {
  template = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [{
      "Effect": "Allow",
      "Action": [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:SendMessage",
        "sqs:SendMessageBatch",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": "$${district_imports_queue_arn}"
   }]
}
EOF

  vars {
    district_imports_queue_arn = "${element(aws_sqs_queue.district_imports_queue.*.arn, count.index)}"
  }

  count = "${length(var.environments)}"
}
