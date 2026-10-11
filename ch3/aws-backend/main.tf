terraform {
  # 要用甚麼provider
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 定義默認區域
provider "aws" {
  region = "ap-east-2"
}

# 建立存放 state file 的 S3 bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "terraform-state-jeeset-pra"
  force_destroy = true
}

# 開啟版本控制：每次 state 被覆寫，舊版本都會保留
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 預設加密：存進 bucket 的檔案自動用 AES-256 加密
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}