import json
import boto3
import time

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')  # <-- set region
table = dynamodb.Table('images')

def lambda_handler(event, context):

    images = [
        {
           "image_name": f"test-{int(time.time())}.jpg",
           "image_url":"https://i.pinimg.com/736x/9c/0d/ac/9c0dac5c0ec22df48e2f352464d1bc20.jpg"
        }
    ]

    for item in images:
        table.put_item(
            Item={
                "image_name": item["image_name"],
                "image_url": item["image_url"]
            }
        )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Inserted into DynamoDB"
        })
    }
