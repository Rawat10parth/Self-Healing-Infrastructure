import random
import pandas as pd
import datetime

# Parameters for synthetic data generation
num_entries = 1440  # Simulate data for one day (1440 minutes)
start_time = datetime.datetime.now() - datetime.timedelta(days=1)
time_interval = datetime.timedelta(minutes=1)

# Initialize synthetic data list
data = []

for i in range(num_entries):
    timestamp = start_time + i * time_interval
    cpu_utilization = round(random.gauss(50, 15), 2)  # Avg 50%, stddev 15%
    memory_usage = round(random.uniform(1024, 4096), 2)  # 1GB to 4GB
    disk_io = round(random.uniform(5, 200), 2)  # 5MBps to 200MBps
    network_in = round(random.uniform(10, 1000), 2)  # 10Mbps to 1Gbps
    network_out = round(random.uniform(10, 1000), 2)  # 10Mbps to 1Gbps
    error_rate = round(random.uniform(0, 5), 2)  # 0% to 5%
    
    data.append([
        timestamp, 
        cpu_utilization, 
        memory_usage, 
        disk_io, 
        network_in, 
        network_out, 
        error_rate
    ])

# Create a DataFrame
columns = [
    "Timestamp", 
    "CPU_Utilization", 
    "Memory_Usage_MB", 
    "Disk_IO_MBps", 
    "Network_In_Mbps", 
    "Network_Out_Mbps", 
    "Error_Rate_Percentage"
]
df = pd.DataFrame(data, columns=columns)

# Save to CSV
df.to_csv("synthetic_cloudwatch_metrics.csv", index=False)
print("Synthetic data saved to 'synthetic_cloudwatch_metrics.csv'")
