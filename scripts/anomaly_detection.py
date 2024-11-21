from sklearn.ensemble import IsolationForest
from scripts import preprocessing
import joblib
import numpy as np
import matplotlib.pyplot as plt

DATA_FILE = "./data/synthetic_cloudwatch_metrics.csv"

def train_anomaly_detection_model(X, model_path, contamination=0.05, n_estimators=100, max_samples="auto"):
    """
    Train an Isolation Forest model to detect anomalies in cloud metrics.
    """
    print("Training anomaly detection model...")
    # Initialize IsolationForest model with provided parameters
    model = IsolationForest(contamination=contamination, n_estimators=n_estimators, max_samples=max_samples, random_state=42)
    model.fit(X)

    # Save the trained model
    print(f"Saving anomaly detection model to {model_path}...")
    joblib.dump(model, model_path)
    
    return model

def predict_anomalies(X, model):
    """
    Predict anomalies in the dataset using the trained Isolation Forest model.
    Returns 1 for normal, -1 for anomaly.
    """
    print("Predicting anomalies...")
    predictions = model.predict(X)  # -1 indicates anomalies, 1 indicates normal
    return predictions

def threshold_based_anomaly_detection(cpu_usage, threshold=50):
    """
    Apply a threshold-based check to detect anomalies based on CPU usage.
    Flags an anomaly if the CPU usage deviates significantly from 50%.
    """
    anomalies = np.abs(cpu_usage - threshold) > threshold * 0.2  # 20% deviation considered as anomaly
    return anomalies

def evaluate_model(predictions, y_true):
    """
    Evaluate the model's performance if true labels (y_true) are available.
    """
    from sklearn.metrics import classification_report, confusion_matrix
    # Create confusion matrix
    cm = confusion_matrix(y_true, predictions)
    print(f"Confusion Matrix:\n{cm}")
    
    # Classification Report for precision, recall, F1-score
    print("Classification Report:")
    print(classification_report(y_true, predictions))

def visualize_anomalies(X, predictions):
    """
    Visualize the anomalies in a 2D feature space (if possible).
    """
    if X.shape[1] == 2:  # If 2D features, we can plot
        plt.scatter(X[:, 0], X[:, 1], c=predictions, cmap='coolwarm')
        plt.title('Anomaly Detection Results')
        plt.xlabel('Feature 1')
        plt.ylabel('Feature 2')
        plt.show()

# Main processing logic
def main():
    # Load and preprocess the synthetic data
    X, y, scaler = preprocessing.load_and_preprocess_data(DATA_FILE)  # X is features, y is true labels for anomalies (or ground truth)

    # Train the anomaly detection model
    model = train_anomaly_detection_model(X, model_path="./models/anomaly_model.pkl", contamination=0.05)

    # Predict anomalies using the Isolation Forest model
    predictions = predict_anomalies(X, model)

    # Apply threshold-based anomaly detection for CPU usage
    cpu_usage = X[:, 0]  # Assuming the first column represents CPU usage in the dataset
    cpu_anomalies = threshold_based_anomaly_detection(cpu_usage)

    # Combine both anomaly detection approaches (machine learning and threshold-based)
    combined_anomalies = np.logical_or(predictions == -1, cpu_anomalies)

    # If you have true anomaly labels 'y', you can evaluate the model
    evaluate_model(combined_anomalies, y)

    # Visualize anomalies (only works if your feature space is 2D)
    visualize_anomalies(X, combined_anomalies)

if __name__ == "__main__":
    main()