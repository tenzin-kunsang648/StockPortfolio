#!/bin/bash

# Quick Start Script for ML Risk Prediction Service

echo "🚀 Setting up ML Risk Prediction Service..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8+ first."
    exit 1
fi

# Check Python version
python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "✅ Python version: $python_version"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Train the model
echo "🧠 Training ML model..."
python train_model.py

# Check if model was created
if [ -f "models/risk_model.pkl" ]; then
    echo "✅ Model trained successfully!"
else
    echo "❌ Model training failed!"
    exit 1
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "To start the API server:"
echo "  python api.py"
echo ""
echo "Or with gunicorn (production):"
echo "  gunicorn -w 4 -b 0.0.0.0:5000 api:app"
echo ""
echo "The API will be available at: http://localhost:5000"
echo ""
echo "For Salesforce integration, see: INTEGRATION_GUIDE.md"

