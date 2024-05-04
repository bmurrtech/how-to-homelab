# Prereqs
- NVIDIA CUDA Drivers
- NVIDIA CUDA Toolkit
- PyTorch
- Tensorflow

## Direct NVIDIA Website Install Method

Use the NVIDIA Official Installer:
- If the package manager still doesn't work, you can download the official NVIDIA driver from the NVIDIA website:
  - Visit the NVIDIA Driver Downloads page.
  - Select your GPU model and Linux distribution.
  - Download the runfile (*.run).

> Before running the installer, you might need to stop your display manager: `sudo systemctl stop [display-manager].service  # e.g., gdm3, lightdm, sddm`

- Make the downloaded script executable and run it:

```bash
chmod +x NVIDIA-Linux-x86_64-xxx.xx.run
sudo ./NVIDIA-Linux-x86_64-xxx.xx.run
```

Follow the on-screen instructions to install the driver.
- Reboot and Verify:
```
sudo reboot
```

- After rebooting, check that the NVIDIA driver is correctly installed:
```
nvidia-smi
```

## NVIDIA CUDA Toolkit
- Check if installed by running:
```
nvcc --version
```
- If the command is not recognized, you must intall the `nvidia-cuda-toolkit`
```
sudo apt install nvidia-cuda-toolkit
```
- After installing `nvcc --version` will display an output (e.g. `Build cuda_11.5.r11.5`).

## Install Pytorch
- Install `pip`
```
sudo apt install python3-pip
```
PyTorch can be installed directly using pip, but the command depends on your CUDA version if you want GPU support. You can visit the PyTorch Get Started page to generate the correct installation command based on your environment. Below are the general instructions for a common setup:

#### For CPU-only Version:
Run the following command in your terminal:
```
pip install torch torchvision torchaudio
```

#### For CUDA Version:
Replace cuXXX with your CUDA version, e.g., cu113 for CUDA 11.3, and run:

```arduino
pip install torch torchvision torchaudio -f https://download.pytorch.org/whl/torch_stable.html
```

> You don't need to change the `torch_stable.html` URL to select a different CUDA version for PyTorch. The CUDA version is implicitly selected by choosing the correct wheel file that matches your CUDA environment, which pip handles automatically when you specify the -f flag with the URL.

## Install TensorFlow
TensorFlow offers separate packages for CPU-only and GPU-enabled installations. Make sure to install the version that matches your system's capabilities. For the GPU version, ensure you have the necessary NVIDIA software installed (CUDA and cuDNN).

#### Install TensorFlow for GPU:
`tensorflow-gpu` has been removed, but `tensorflow` works because the [tensorflow](https://pypi.org/project/tensorflow-gpu/) package supports GPU accelerated operations via Nvidia CUDA.
- Run the following command in your terminal:
```
pip install tensorflow
```

> Additional Notes:
> Python Version: Ensure you are using a Python version supported by both TensorFlow and PyTorch. As of now, Python 3.6 to 3.9 are generally supported.
> Virtual Environment: It is highly recommended to install these libraries within a virtual environment to manage dependencies effectively and avoid conflicts with system packages.
> To create and activate a virtual environment, run:
> ```bash
> python -m venv myenv
> source myenv/bin/activate
> ```
> Update pip: Ensure that your pip is up-to-date before installing:
```
pip install --upgrade pip
```
> CUDA/CuDNN: For TensorFlow with GPU, you usually need specific versions of CUDA and cuDNN. Check TensorFlow's official documentation to confirm which versions are required for the latest TensorFlow release.

# Troubleshooting Mismatched CUDA Version
You can confirm a mismatch by running the following: 
```
nvidia-smi       # Your Actual CUDA version
nvcc --version  # Should show CUDA <same version>
```

#### Steps to Resolve the Discrepancy
Aligning your CUDA toolkit version with your driver/runtime version is crucial for ensuring that your deep learning environments are stable and can fully utilize GPU acceleration. This will likely resolve the issue of the LLM defaulting to CPU usage and improve overall performance.

#### Align CUDA Toolkit and Driver Versions
- You have two main options here:
  - Upgrade the CUDA Toolkit: Update your CUDA toolkit to match the installed driver version (CUDA 12.4), which is generally the recommended approach if you want to leverage the latest features and improvements.
  - Downgrade the CUDA Drivers: Revert your CUDA drivers to match the toolkit version you have installed (CUDA 11.5). This might be necessary if you have specific dependencies on the older toolkit version or if newer versions are not yet supported by your applications.

#### Installing or Upgrading CUDA Toolkit
- Download the Newer CUDA Toolkit: Go to the [NVIDIA CUDA Toolkit webpage and download the installer for CUDA 12.4](https://developer.nvidia.com/cuda-downloads), which matches your driver version.
- Installation Instructions: Follow the instructions provided by NVIDIA for installation, which typically include running the downloaded installer and following the on-screen prompts.

#### Post-Installation:
Update your environment variables, if necessary:
```
export PATH=/usr/local/cuda-12.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH
```
- Reboot the system to ensure all changes are applied correctly.

#### Verify the Installation
After installation, verify that the new version is correctly installed and recognized:
```
nvcc --version  # Should now show CUDA 12.4
nvidia-smi       # Should be compatible with CUDA 12.4
```

#### Reinstall Deep Learning Frameworks
With the new CUDA version installed, it's often necessary to reinstall your deep learning frameworks to ensure they are built against the correct CUDA version:
```
pip uninstall tensorflow  # or pytorch
pip install tensorflow-gpu  # or the appropriate pytorch version
```

# Install Ollama
See [Ollama Github](https://github.com/ollama/ollama) for instructions.

## Quickstart Install (Linux)
For Linux: use the curl command to install:

```
curl -fsSL https://ollama.com/install.sh | sh
```

## Install LLM
Find your LLM of choice from the [Ollama library](https://ollama.com/library) and download it via Termail with:

```
ollama pull <LLM>

# E.g. ollama pull llama3
```
