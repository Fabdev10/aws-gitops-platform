terraform {
  backend "s3" {
    # Create this bucket/table once (outside this stack) before terraform init.
    bucket         = "aws-gitops-platform-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-gitops-platform-tf-locks"
    encrypt        = true
  }
}
