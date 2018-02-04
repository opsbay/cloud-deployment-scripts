resource "aws_codedeploy_deployment_config" "tf-codedeploy-config-quarteratatime" {
  deployment_config_name = "Naviance.QuarterAtATime"

  minimum_healthy_hosts {
    type  = "FLEET_PERCENT"
    value = 75
  }
}
