ARG BASE_IMAGE=docker.io/library/almalinux:8
ARG VERSION=v2024.2.2.2

FROM $BASE_IMAGE as builder
ARG VERSION

ENV YB_HOME=/home/yugabyte
WORKDIR $YB_HOME

# Install dev tools & dependencies
RUN dnf update -y && \
    dnf groupinstall -y 'Development Tools' && \
    dnf install -y epel-release && \
    dnf install -y \
        ccache \
        gcc-toolset-11 \
        gcc-toolset-11-libatomic-devel \
        golang \
        java-1.8.0-openjdk \
        libatomic \
        maven \
        npm \
        patchelf \
        python39 \
        python39-devel \
        rsync && \
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    alternatives --set python3 /usr/bin/python3.9 && \
    dnf clean all

# Install Ninja (latest from GitHub)
RUN arch=$(uname -m) && \
    if [ "$arch" = "x86_64" ]; then \
        zip_name="ninja-linux.zip"; \
    elif [ "$arch" = "aarch64" ]; then \
        zip_name="ninja-linux-aarch64.zip"; \
    else \
        echo "Unsupported architecture: $arch" && exit 1; \
    fi && \
    curl -Ls "https://api.github.com/repos/ninja-build/ninja/releases/latest" \
    | grep browser_download_url \
    | grep "$zip_name" \
    | cut -d '"' -f 4 \
    | xargs curl -Ls \
    | zcat > /usr/local/bin/ninja && \
    chmod +x /usr/local/bin/ninja

# Install CMake
RUN arch=$(uname -m) && \
    mkdir -p /root/tools && \
    curl -L "https://github.com/Kitware/CMake/releases/download/v3.31.0/cmake-3.31.0-linux-${arch}.tar.gz" \
    | tar -xz -C /root/tools && \
    for f in /root/tools/cmake-3.31.0-linux-${arch}/bin/*; do \
      ln -s "$f" /usr/local/bin/$(basename "$f"); \
    done && \
    which cmake && cmake --version

# Prepare build directory
RUN mkdir -p /opt/yb-build && chown root:root /opt/yb-build

# Clone and build YugabyteDB
RUN git clone https://github.com/yugabyte/yugabyte-db.git $YB_HOME/yugabyte-db

RUN cd $YB_HOME/yugabyte-db && \
    git checkout $VERSION && \
    ./yb_build.sh --scb --sj release

# Final image
FROM $BASE_IMAGE
COPY --from=builder /opt/yb-build /opt/yb-build

# Optional: add built binaries or source if needed
COPY --from=builder /home/yugabyte/yugabyte-db /home/yugabyte/yugabyte-db

WORKDIR /home/yugabyte/yugabyte-db
CMD ["bash"]

