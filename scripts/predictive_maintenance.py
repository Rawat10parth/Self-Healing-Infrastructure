from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import mean_squared_error, r2_score
import joblib
import os
import numpy as np
import logging

def setup_logger():
    """
    Set up a logger for tracking model training and evaluation steps.
    """
    logger = logging.getLogger('PredictiveMaintenance')
    logger.setLevel(logging.DEBUG)
    handler = logging.FileHandler('predictive_maintenance.log')
    handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger

def train_predictive_maintenance_model(X, y, model_path, n_estimators=100, max_depth=None, random_state=42):
    """
    Train a regression model to predict error rates.
    """
    logger = setup_logger()
    
    # Splitting data into training and testing sets
    logger.info("Splitting data into training and testing sets...")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=random_state)
    
    # Model initialization
    logger.info("Training Random Forest regression model...")
    model = RandomForestRegressor(n_estimators=n_estimators, max_depth=max_depth, random_state=random_state)
    model.fit(X_train, y_train)
    
    # Cross-validation
    logger.info("Performing cross-validation...")
    cv_scores = cross_val_score(model, X_train, y_train, cv=5, scoring='neg_mean_squared_error')
    avg_cv_score = np.mean(cv_scores)
    logger.info(f"Average cross-validation MSE: {-avg_cv_score:.2f}")
    
    # Evaluating the model
    logger.info("Evaluating the model...")
    y_pred = model.predict(X_test)
    mse = mean_squared_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    
    logger.info(f"Mean Squared Error: {mse:.2f}")
    logger.info(f"R2 Score: {r2:.2f}")
    
    # Feature importance (Handle X as NumPy array)
    feature_importances = model.feature_importances_
    logger.info("Feature importances:")
    for i, importance in enumerate(feature_importances):
        logger.info(f"Feature {i}: {importance:.4f}")
    
    # Save model
    logger.info("Saving regression model...")
    model_dir = os.path.dirname(model_path)
    if not os.path.exists(model_dir):
        os.makedirs(model_dir)
    
    try:
        joblib.dump(model, model_path)
        logger.info(f"Model successfully saved to {model_path}")
    except Exception as e:
        logger.error(f"Error saving model: {e}")
    
    return model