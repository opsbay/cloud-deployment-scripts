terraform {
  backend "s3" {
    key     = "base/terraform.tfstate"
    encrypt = true
  }
}
