import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import KMeans
import matplotlib.pyplot as plt
import joblib
import os


def preprocess_logs(log_file):
    """
    Preprocess log messages by removing timestamps and special characters.
    """
    with open(log_file, "r") as file:
        logs = file.readlines()
    processed_logs = [re.sub(r"\d{4}-\d{2}-\d{2}.*- ", "", log.strip()) for log in logs]
    return processed_logs


def categorize_logs(processed_logs, num_clusters=3):
    """
    Categorize log messages using TF-IDF and KMeans clustering, and save models.
    """
    # TF-IDF Vectorizer
    vectorizer = TfidfVectorizer(stop_words="english")
    X = vectorizer.fit_transform(processed_logs)
    
    # KMeans Clustering
    kmeans = KMeans(n_clusters=num_clusters, random_state=42)
    kmeans.fit(X)
    log_clusters = kmeans.predict(X)
    
    # Save the TF-IDF vectorizer
    tfidf_vectorizer_path = "./models/tfidf_vectorizer.pkl"
    os.makedirs("./models", exist_ok=True)
    print(f"Saving TF-IDF vectorizer to {tfidf_vectorizer_path}...")
    joblib.dump(vectorizer, tfidf_vectorizer_path)

    # Save the clustering model
    log_clustering_model_path = "./models/log_clustering_model.pkl"
    print(f"Saving log clustering model to {log_clustering_model_path}...")
    joblib.dump(kmeans, log_clustering_model_path)

    return log_clusters, processed_logs


def visualize_clusters(log_clusters, processed_logs, num_clusters):
    """
    Visualize and save log messages by cluster.
    """
    os.makedirs("./visualizations", exist_ok=True)

    # Print clusters to console
    for i in range(num_clusters):
        print(f"Cluster {i} Logs:")
        for idx, log in enumerate(processed_logs):
            if log_clusters[idx] == i:
                print(log)
        print()

    # Save the cluster visualization plot
    plt.figure(figsize=(10, 6))
    plt.hist(log_clusters, bins=num_clusters, color="blue", edgecolor="black")
    plt.title("Log Clusters Distribution")
    plt.xlabel("Cluster ID")
    plt.ylabel("Number of Logs")
    output_path = "./visualizations/log_clusters_visualization.png"
    print(f"Saving log clusters visualization to {output_path}...")
    plt.savefig(output_path)


def save_clustered_logs(log_clusters, processed_logs, output_file="../data/log_clusters.txt"):
    """
    Save categorized logs into a file grouped by clusters.
    """
    # Ensure the parent directory exists
    data_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../data")
    os.makedirs(data_folder, exist_ok=True)
    
    # Full file path
    output_file = os.path.join(data_folder, "log_clusters.txt")
    
    # Save the logs to the specified file
    with open(output_file, "w") as file:
        for cluster in range(max(log_clusters) + 1):
            file.write(f"Cluster {cluster} Logs:\n")
            for idx, log in enumerate(processed_logs):
                if log_clusters[idx] == cluster:
                    file.write(f"- {log}\n")
            file.write("\n")

    print(f"Clustered logs saved to {output_file}")
