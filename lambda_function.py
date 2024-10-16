import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    instance_id = event['detail']['instance-id']
    
    try:
        response = ec2.reboot_instances(InstanceIds=[instance_id])
        return {
            'statusCode': 200,
            'body': f'Instance {instance_id} rebooted successfully'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error rebooting instance: {str(e)}'
        }