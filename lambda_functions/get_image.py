import boto3
import json

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        params = event.get("queryStringParameters")

        if not params or "image_name" not in params:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "image_name is required"})
            }

        image_name = params["image_name"]

        url = s3.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": "deepdust-store-image",  # FIXED
                "Key": image_name
            },
            ExpiresIn=3600
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "image_url": url
            })
        }

    except Exception as e:
        print("ERROR:", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }
