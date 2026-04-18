variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to keep."
  type        = number
  default     = 50
}

variable "tags" {
  description = "Standard tags applied to ECR resources."
  type        = map(string)
  default     = {}
}
