variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket name — must be globally unique across all of AWS"
  type        = string
  default     = "deepdust-image-store-2024"
}
