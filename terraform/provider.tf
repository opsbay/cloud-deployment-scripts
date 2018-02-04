# This will default to using ~/.aws/credentials
# If run on an EC2 instance, it will querey the metadata service
# So make sure that instances that will run terraform (Jenkins) have
# an appropriate role associated with them,
provider "aws" {
  version = "1.6.0"
}

# https://www.terraform.io/docs/providers/archive/index.html
provider "archive" {
  version = "1.0.0"
}

# https://www.terraform.io/docs/providers/template/index.html
provider "template" {
  version = "1.0.0"
}
