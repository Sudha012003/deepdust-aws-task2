Event-Driven Image Processing System (AWS Serverless)
Overview

This project implements a scalable, event-driven image processing pipeline using AWS serverless services. The system automatically ingests image metadata from an external API, processes images asynchronously, stores them in S3, and exposes retrieval APIs.

It demonstrates a clear understanding of event-driven architecture using AWS Lambda, API Gateway, DynamoDB Streams, and S3.

Architecture
Flow
Client calls /image_url API
Lambda fetches image data from external API (Shopprop - Napa region)
Image metadata is stored in DynamoDB
DynamoDB Stream triggers another Lambda
Lambda downloads image and uploads to S3
Client calls /get-image API
Lambda returns image URL (or pre-signed URL) and metadata
Tech Stack
AWS Lambda
Amazon API Gateway
Amazon DynamoDB (with Streams enabled)
Amazon S3
Python (or Node.js, depending on implementation)
Project Structure
.
├── lambdas/
│   ├── ingestion_lambda/
│   ├── stream_processor_lambda/
│   └── retrieval_lambda/
├── infrastructure/
│   └── (CloudFormation / Terraform / SAM templates)
├── utils/
├── requirements.txt
└── README.md
APIs
1. Image Ingestion API

Endpoint:
POST /image_url

Description:
Fetches image data from external API and stores metadata in DynamoDB.

Process:

Calls Shopprop API (region: napa)
Extracts:
image_name
image_url
Stores data in DynamoDB

Response Example:

{
  "message": "Image metadata stored successfully",
  "image_name": "sample_image.jpg"
}
2. Image Retrieval API

Endpoint:
GET /get-image

Query Params:

image_name

Description:
Retrieves image from S3 and returns access URL and metadata.

Response Example:

{
  "image_name": "sample_image.jpg",
  "image_url": "https://<bucket>.s3.amazonaws.com/sample_image.jpg",
  "last_modified": "2026-04-23T10:00:00Z"
}
AWS Resources
1. Lambda Functions
a. Ingestion Lambda
Triggered by API Gateway
Fetches image data
Writes to DynamoDB
b. Stream Processor Lambda
Triggered by DynamoDB Streams
Downloads image from URL
Uploads image to S3
c. Retrieval Lambda
Triggered by API Gateway
Fetches image metadata
Generates pre-signed URL (optional)
2. DynamoDB
Table Name: ImageMetadata
Primary Key: image_name
Streams: Enabled (NEW_IMAGE)

Attributes:

image_name
image_url
created_at
3. S3
Bucket stores downloaded images
File name = image_name
Setup Instructions
Prerequisites
AWS CLI configured
IAM permissions for Lambda, DynamoDB, S3, API Gateway
Python 3.x or Node.js
Deployment Steps
Create DynamoDB table with Streams enabled
Create S3 bucket
Deploy Lambda functions
Configure DynamoDB Stream trigger
Create API Gateway endpoints:
/image_url
/get-image
Connect APIs to respective Lambdas
Error Handling
Invalid API response handling
Missing fields validation
S3 upload failures
Network timeouts
DynamoDB write failures
Key Features
Fully serverless architecture
Event-driven processing
Scalable and fault-tolerant
Loose coupling via DynamoDB Streams
Secure image access via pre-signed URLs
Future Improvements
Add authentication (JWT / Cognito)
Add image transformation (resize, compression)
Implement retries with DLQ (Dead Letter Queue)
Add logging and monitoring (CloudWatch)
Batch processing support
Author

K SUDHA B ADIGA

License

This project is for educational and internship evaluation purposes.
