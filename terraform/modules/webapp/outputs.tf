output "alb_arns" {
  value = ["${aws_alb.alb.*.arn}"]
}
