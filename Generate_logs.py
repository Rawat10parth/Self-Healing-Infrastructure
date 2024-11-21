import random
import datetime

# Parameters for log generation
num_logs = 1000
start_time = datetime.datetime.now() - datetime.timedelta(hours=2)
log_interval = datetime.timedelta(seconds=30)

# Log levels and messages
log_levels = ["INFO", "WARN", "ERROR", "DEBUG"]
log_messages = [
    "Application started successfully",
    "Database connection established",
    "Disk usage nearing capacity",
    "Unexpected error occurred in module X",
    "High memory usage detected",
    "Network latency exceeded threshold",
    "Auto-scaling triggered new instance launch"
]

# Generate synthetic logs
logs = []

for i in range(num_logs):
    timestamp = start_time + i * log_interval
    log_level = random.choice(log_levels)
    log_message = random.choice(log_messages)
    log_entry = f"{timestamp} - {log_level} - {log_message}"
    logs.append(log_entry)

# Save to a log file
with open("synthetic_cloudwatch_logs.log", "w") as log_file:
    log_file.write("\n".join(logs))

print("Synthetic logs saved to 'synthetic_cloudwatch_logs.log'")
