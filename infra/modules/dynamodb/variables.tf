variable "name" {
  description = "Prefix used for the DynamoDB table name."
  type        = string
}

variable "tags" {
  description = "Standard resource tags."
  type        = map(string)
  default     = {}
}
