# tests/Dockerfile: Ephemeral test and developer exploration sandbox for AI Automation Engineer Workstation
# NOTE: This image is strictly intended for automated CI verification (tests/verify_container.sh)
# and local developer interactive sandboxing (tests/sandbox.sh). It simulates a standard single-user
# Ubuntu 24.04 workstation or cloud VM (e.g. AWS EC2 'ubuntu' with sudo) to test apt installations.
# It does NOT mount the host Docker socket (/var/run/docker.sock) and is NOT intended as a hardened production container runtime.

FROM ubuntu:24.04

# Avoid interactive prompts during base image setup
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install sudo and ca-certificates so testuser can run sudo apt-get
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a regular non-root user 'testuser' with passwordless sudo (just like standard cloud/desktop Ubuntu user)
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory to testuser's home
WORKDIR /home/testuser

# Switch to non-root user
USER testuser

# Copy the repository into the user's home
COPY --chown=testuser:testuser . /home/testuser/ai-automation-engineer-workstation
RUN ln -s /home/testuser/ai-automation-engineer-workstation /home/testuser/dotfiles

WORKDIR /home/testuser/ai-automation-engineer-workstation

# Default command runs the test suite
CMD ["/bin/bash", "tests/verify_container.sh"]
