import pandas as pd
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.decomposition import PCA
from sklearn.feature_selection import mutual_info_regression
import numpy as np


def load_and_preprocess_data(file_path, n_components=None, drop_columns=["Timestamp", "Error_Rate_Percentage"]):
    """
    Load and preprocess the synthetic data:
    - Handle missing values.
    - Remove unnecessary columns.
    - Normalize the features.
    - Optionally reduce dimensionality using PCA.
    - Perform feature selection based on mutual information.
    """
    print("Loading synthetic data...")
    df = pd.read_csv(file_path)

    # Step 1: Handle missing values
    print("Handling missing values...")
    missing_values = df.isnull().sum()
    if missing_values.any():
        print(f"Missing values detected:\n{missing_values}")
        print("Imputing missing values using mean strategy...")
        imputer = SimpleImputer(strategy="mean")
        df.iloc[:, :] = imputer.fit_transform(df)

    # Step 2: Drop unnecessary columns
    print(f"Dropping unnecessary columns: {drop_columns}")
    X = df.drop(columns=drop_columns)
    y = df["Error_Rate_Percentage"]

    # Step 3: Remove constant or quasi-constant features
    print("Removing constant or quasi-constant features...")
    n_unique = X.nunique()
    quasi_constant_features = n_unique[n_unique <= 1].index.tolist()
    if quasi_constant_features:
        print(f"Removing features: {quasi_constant_features}")
        X = X.drop(columns=quasi_constant_features)

    # Step 4: Detect and handle outliers (using z-scores)
    print("Detecting and removing outliers...")
    z_scores = np.abs((X - X.mean()) / X.std())
    threshold = 3  # Z-score threshold for identifying outliers
    outliers = (z_scores > threshold).any(axis=1)
    if outliers.sum() > 0:
        print(f"Removing {outliers.sum()} outliers...")
        X = X[~outliers]
        y = y[~outliers]

    # Step 5: Normalize the data
    print("Normalizing data...")
    scaler = MinMaxScaler()
    X_normalized = scaler.fit_transform(X)

    # Step 6: Feature selection based on mutual information
    print("Performing feature selection based on mutual information...")
    mutual_info = mutual_info_regression(X_normalized, y)
    selected_features = X.columns[mutual_info > 0.01]  # Retain features with non-trivial mutual info
    print(f"Selected features: {list(selected_features)}")
    X_normalized = X_normalized[:, mutual_info > 0.01]

    # Step 7: Optional dimensionality reduction (PCA)
    if n_components:
        print(f"Reducing dimensions to {n_components} components using PCA...")
        pca = PCA(n_components=1)
        X_normalized = pca.fit_transform(X_normalized)
        print(f"Explained variance ratio by PCA: {pca.explained_variance_ratio_}")

    return X_normalized, y, scaler 