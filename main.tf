terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# S3 BUCKET
# ─────────────────────────────────────────
resource "aws_s3_bucket" "image_store" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Project = "DeepDust"
  }
}

resource "aws_s3_bucket_ownership_controls" "image_store" {
  bucket = aws_s3_bucket.image_store.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "image_store" {
  bucket                  = aws_s3_bucket.image_store.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────
# DYNAMODB TABLE
# ─────────────────────────────────────────
resource "aws_dynamodb_table" "images" {
  name         = "images"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_name"

  attribute {
    name = "image_name"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = {
    Project = "DeepDust"
  }
}

# ─────────────────────────────────────────
# IAM ROLE FOR ALL LAMBDAS
# ─────────────────────────────────────────
resource "aws_iam_role" "lambda_role" {
  name = "lambda-image-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-image-processor-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = [
          aws_dynamodb_table.images.arn,
          "${aws_dynamodb_table.images.arn}/stream/*"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:HeadObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.image_store.arn,
          "${aws_s3_bucket.image_store.arn}/*"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────
# LAMBDA ZIP PACKAGES
# ─────────────────────────────────────────
data "archive_file" "ingest_image_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/ingest_image.py"
  output_path = "${path.module}/lambda_functions/ingest_image.zip"
}

data "archive_file" "stream_processor_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/stream_processor.py"
  output_path = "${path.module}/lambda_functions/stream_processor.zip"
}

data "archive_file" "get_image_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/get_image.py"
  output_path = "${path.module}/lambda_functions/get_image.zip"
}

# ─────────────────────────────────────────
# LAMBDA 1 — ingest_image
# ─────────────────────────────────────────
resource "aws_lambda_function" "ingest_image" {
  function_name    = "ingest_image"
  role             = aws_iam_role.lambda_role.arn
  handler          = "ingest_image.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ingest_image_zip.output_path
  source_code_hash = data.archive_file.ingest_image_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  tags = { Project = "DeepDust" }
}

# ─────────────────────────────────────────
# LAMBDA 2 — stream_processor
# ─────────────────────────────────────────
resource "aws_lambda_function" "stream_processor" {
  function_name    = "stream_processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "stream_processor.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.stream_processor_zip.output_path
  source_code_hash = data.archive_file.stream_processor_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.image_store.bucket
    }
  }

  tags = { Project = "DeepDust" }
}

resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  event_source_arn  = aws_dynamodb_table.images.stream_arn
  function_name     = aws_lambda_function.stream_processor.arn
  starting_position = "LATEST"
  batch_size        = 10
}

# ─────────────────────────────────────────
# LAMBDA 3 — get_image
# ─────────────────────────────────────────
resource "aws_lambda_function" "get_image" {
  function_name    = "get_image"
  role             = aws_iam_role.lambda_role.arn
  handler          = "get_image.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.get_image_zip.output_path
  source_code_hash = data.archive_file.get_image_zip.output_base64sha256
  timeout          = 15
  memory_size      = 128

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.image_store.bucket
    }
  }

  tags = { Project = "DeepDust" }
}

# ─────────────────────────────────────────
# API GATEWAY
# ─────────────────────────────────────────
resource "aws_api_gateway_rest_api" "image_api" {
  name        = "image-processor-api"
  description = "DeepDust Image Processing API"
}

# ── /image_url resource ──
resource "aws_api_gateway_resource" "image_url" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  parent_id   = aws_api_gateway_rest_api.image_api.root_resource_id
  path_part   = "image_url"
}

resource "aws_api_gateway_method" "post_image_url" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.image_url.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_image_url" {
  rest_api_id             = aws_api_gateway_rest_api.image_api.id
  resource_id             = aws_api_gateway_resource.image_url.id
  http_method             = aws_api_gateway_method.post_image_url.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ingest_image.invoke_arn
}

resource "aws_lambda_permission" "apigw_ingest" {
  statement_id  = "AllowAPIGatewayIngest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_image.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_api.execution_arn}/*/*"
}

# ── /get-image resource ──
resource "aws_api_gateway_resource" "get_image" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  parent_id   = aws_api_gateway_rest_api.image_api.root_resource_id
  path_part   = "get-image"
}

resource "aws_api_gateway_method" "get_image_method" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.get_image.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.image_name" = true
  }
}

resource "aws_api_gateway_integration" "get_image_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_api.id
  resource_id             = aws_api_gateway_resource.get_image.id
  http_method             = aws_api_gateway_method.get_image_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_image.invoke_arn
}

resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowAPIGatewayGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_image.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_api.execution_arn}/*/*"
}

# ── Deploy ──
resource "aws_api_gateway_deployment" "prod" {
  depends_on = [
    aws_api_gateway_integration.post_image_url,
    aws_api_gateway_integration.get_image_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.image_api.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  stage_name    = "prod"
}
