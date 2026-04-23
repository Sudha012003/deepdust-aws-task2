import boto3
import urllib.request

s3 = boto3.client('s3', region_name='ap-east-1')  # FIX REGION

def lambda_handler(event, context):

    print("EVENT:", event)

    for record in event['Records']:

        image_name = record['dynamodb']['NewImage']['image_name']['S']
        image_url = record['dynamodb']['NewImage']['image_url']['S']

        print("Downloading:", image_url)

        with urllib.request.urlopen(image_url) as response:
            image_data = response.read()

        print("Uploading to S3:", image_name)

        s3.put_object(
            Bucket="deepdust-image-store",
            Key=image_name,
            Body=image_data
        )

        print("Upload complete")

    return "Uploaded to S3"
