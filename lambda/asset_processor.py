import json
import urllib.parse

def lambda_handler(event, context):
    # Parse the bucket name and filename directly out of the S3 Event Notification record
    try:
        for record in event.get('Records', []):
            bucket_name = record['s3']['bucket']['name']
            # Decode the filename to cleanly handle spaces or special characters
            file_key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
            
            # CRITICAL LOGGING OUTPUT SPECIFIED BY THE CAPSTONE BRIEF:
            print(f"Image received: {file_key}")
            
        return {
            'statusCode': 200,
            'body': json.dumps('Asset tracked successfully in CloudWatch logs.')
        }
    except Exception as e:
        print(f"Error processing event record: {str(e)}")
        raise e
