#!/bin/bash

# Name of the conda environment an jupyter kernel
ENV_NAME="codellama7binstruct"
KERNEL_NAME="$ENV_NAME"

# Set sutup.log, .env, and git_repo as variables
LOG_FILE="$ROOT_PATH/setup.log"

# PIP packages
pip_packages=(
  "diffusers"
  "transformers"
  "accelerate"
  "python-dotenv"
  )

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "starting script... \n"

# Debugging: Uncomment the following line if you want to log all terminal output (bash -x is preferred)
# exec > >(tee -a "$LOG_FILE")

# Trap error and write to log file
trap 'log "\n$(date) - Error occurred in ${BASH_SOURCE[0]} at line ${LINENO}: $? - $BASH_COMMAND\n" >> "$LOG_FILE"' ERR

# Debugging: Test the error trap by using a failing command
log "Testing the error trap..."
false

# Create and activate conda environment
if conda info --envs | grep -q "$ENV_NAME"; then
  log "Conda environment $ENV_NAME already exists"
else
  log "Creating conda environment $ENV_NAME"
  conda create --name $ENV_NAME python=3.8 -y && log "Conda environment created successfully" || log "Failed to create conda environment "
fi

# If current conda env does not match ENV_NAME; activate ENV_NAME
if [ "$(conda info --envs | grep '*' | grep -o "$ENV_NAME")" == "" ]; then
  # When conda activate errors out requesting conda init to be run, the eval expression here makes it work without conda init.
  eval "$(conda shell.bash hook)"
  conda activate $ENV_NAME && log "Conda environment $ENV_NAME activated successfully" || {
  log "Conda environment failed to activate";
  exit 1;
}
fi

# Install PyTorch and related libraries
conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y && log "PyTorch/Cuda installed successfully \n" || {
  log "Pytorch/Cuda installation failed \n";
  exit 1;
  }

# Install additional Python packages
for package in ${pip_packages[@]}; do
  pip install $package && log "$package installed successfully" || log "Failed to install $package"
done

# Install Jupyter and create a kernel
conda install -c conda-forge jupyter ipykernel -y && log "ipykernel installed successfuly"
python -m ipykernel install --user --name "$ENV_NAME" --display-name "$KERNEL_NAME" && log "Jupyter kernel created successfully \n" || log "Failed to create Jupyter kernel /n"