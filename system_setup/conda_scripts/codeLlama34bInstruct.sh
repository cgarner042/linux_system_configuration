#!/bin/bash

# Name of the conda environment
ENV_NAME="codeLlama34bInstruct"

# Create and activate conda environment
conda create --name $ENV_NAME python=3.8 -y
source activate $ENV_NAME

# Install PyTorch and related libraries
conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y

# Install additional Python packages
pip install diffusers transformers accelerate

# Install Jupyter and create a kernel
conda install -c conda-forge jupyter ipykernel -y
python -m ipykernel install --user --name=$ENV_NAME --display-name "Python ($ENV_NAME)"

# Clone the GitHub repository
git clone https://github.com/meta-llama/codellama.git
cd codellama

# Install the repository in editable mode
pip install -e .

