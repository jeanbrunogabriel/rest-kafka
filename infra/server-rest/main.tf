provider "aws" {
  profile = "jeanbraga"
  region  = "us-east-1"
}

terraform {
  backend "s3" {}
}
