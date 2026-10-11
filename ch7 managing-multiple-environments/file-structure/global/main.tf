terraform {
  # Assumes s3 bucket and dynamo DB table already set up
  # See /code/ch3/aws-backend
  backend "s3" {
    bucket         = "terraform-state-jeeset-pra"
    key            = "ch7 managing-multiple-environments/global/terraform.tfstate"
    region         = "ap-east-2"
    use_lockfile   = true
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-east-2"
}

# Route53 zone is shared across staging and production
resource "aws_route53_zone" "primary" {
  name = "devopsdeployed.com"
}