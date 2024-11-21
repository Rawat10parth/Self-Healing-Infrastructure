import numpy as np
import pandas as pd
from scripts import preprocessing, anomaly_detection, predictive_maintenance, log_analysis

# File paths
DATA_FILE = "./data/synthetic_cloudwatch_metrics.csv"
ANOMALY_MODEL_FILE = "./models/anomaly_model.pkl"
REGRESSION_MODEL_FILE = "./models/trained_model.pkl"
LOG_FILE = "./data/synthetic_cloudwatch_logs.log"

def main():
    # Step 1: Preprocess the data
    print("=== Step 1: Preprocessing Data ===")
    # You can now pass n_components to use PCA if needed
    X, y, scaler = preprocessing.load_and_preprocess_data(DATA_FILE, n_components=5)  # 5 components for PCA

    # Step 2: Train anomaly detection model
    print("\n=== Step 2: Training Anomaly Detection Model ===")
    anomaly_model = anomaly_detection.train_anomaly_detection_model(X, ANOMALY_MODEL_FILE)  # Train Isolation Forest
    anomaly_predictions = anomaly_detection.predict_anomalies(X, anomaly_model)  # Predict anomalies with Isolation Forest
    
    # Apply threshold-based anomaly detection for CPU usage (assuming CPU usage is in the first column)
    cpu_usage = X[:, 0]  # Assuming CPU usage is in the first feature column
    cpu_anomalies = anomaly_detection.threshold_based_anomaly_detection(cpu_usage)

    # Combine results from both methods: Isolation Forest and CPU usage threshold detection
    combined_anomalies = np.logical_or(anomaly_predictions == -1, cpu_anomalies)

    # Output number of anomalies detected
    print(f"Anomalies detected (combined method): {sum(combined_anomalies)}")

    # Step 3: Train predictive maintenance model
    print("\n=== Step 3: Training Predictive Maintenance Model ===")
    regression_model = predictive_maintenance.train_predictive_maintenance_model(
        X, y, REGRESSION_MODEL_FILE, n_estimators=100, max_depth=10
    )  # Train with hyperparameters: n_estimators and max_depth


    # Step 4: Log Analysis using NLP model
    print("\n=== Step 4: Log Analysis using NLP model ===")
    # Log analysis
    processed_logs = log_analysis.preprocess_logs(LOG_FILE)  # Preprocess logs
    log_clusters, processed_logs = log_analysis.categorize_logs(processed_logs)  # Categorize logs
    log_analysis.visualize_clusters(log_clusters, processed_logs, num_clusters=3)  # Visualize the log clusters
    
    # Specify the correct path for saving the clustered logs
    output_file = "../data/log_clusters.txt"  # Path to the 'data' folder
    log_analysis.save_clustered_logs(log_clusters, processed_logs, output_file=output_file)

    print("Clustered logs saved to log_clusters.txt.")


if __name__ == "__main__":
    main()