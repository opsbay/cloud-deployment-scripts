output "asg_arns" {
  value = ["${aws_autoscaling_group.utilitynode-asg.*.arn}"]
}

output "alb_arns" {
  value = ["${aws_alb.utilitynode-alb.*.arn}"]
}
