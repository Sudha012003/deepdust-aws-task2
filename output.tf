output "api_base_url" {
  description = "Base URL of the deployed API Gateway"
  value       = "https://${aws_api_gateway_rest_api.image_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

output "post_image_url_endpoint" {
  description = "Full URL for POST /image_url"
  value       = "https://${aws_api_gateway_rest_api.image_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/image_url"
}

output "get_image_endpoint" {
  description = "Full URL for GET /get-image"
  value       = "https://${aws_api_gateway_rest_api.image_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/get-image?image_name=YOUR_IMAGE_NAME"
}

output "s3_bucket_name" {
  description = "S3 bucket storing the images"
  value       = aws_s3_bucket.image_store.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.images.name
}

output "dynamodb_stream_arn" {
  description = "DynamoDB stream ARN"
  value       = aws_dynamodb_table.images.stream_arn
}
