import boto3

logs_client = boto3.client('logs')

log_group_name = "/ec2/instance-logs"

try:
    streams = logs_client.describe_log_streams(logGroupName=log_group_name)['logStreams']
    if not streams:
        print(f"No log streams found in log group {log_group_name}.")
    else:
        for stream in streams:
            log_stream_name = stream['logStreamName']
            try:
                events = logs_client.get_log_events(
                    logGroupName=log_group_name,
                    logStreamName=log_stream_name
                )
                for event in events['events']:
                    print(event['message'])
            except Exception as e:
                print(f"Error fetching events from {log_stream_name}: {e}")
except Exception as e:
    print(f"Error accessing log group {log_group_name}: {e}")
