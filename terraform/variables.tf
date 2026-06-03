variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The target AWS region enforced by grading criteria."
}

variable "student_id" {
  type        = string
  default     = "jaeybee98" # Enforces unique identifier across storage resources
  description = "Your unique identifier used for S3 bucket suffixes."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Base CIDR block for Project Bedrock VPC."
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "Target availability zones for high availability."
}
