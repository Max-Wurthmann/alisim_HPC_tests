FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

# directory to store iqtree source code
ARG SRC_DIR=/usr/local/src/iqtree2
# number of processors to use for compilation
ARG N_PROCS=8

# install deps: git, eigen3, boost, OpenMPI, OpenMP, and other utils
RUN apt-get update && apt-get install -y \ 
  wget \
  build-essential \
  software-properties-common \
  git \
  libeigen3-dev \
  libboost-all-dev \
  libopenmpi-dev \
  openmpi-bin \
  libomp-dev \
  vim-tiny \
  time \
  && rm -rf /var/lib/apt/lists/*

# install cmake 3.1
RUN wget https://cmake.org/files/v3.1/cmake-3.1.0-Linux-x86_64.tar.gz \
  && tar -xzf cmake-3.1.0-Linux-x86_64.tar.gz \
  && rm cmake-3.1.0-Linux-x86_64.tar.gz \
  && mv cmake-3.1.0-Linux-x86_64 /opt/cmake-3.1 \
  && ln -s /opt/cmake-3.1/bin/cmake /usr/local/bin/cmake

# install Clang 4.0
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
  && echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-4.0 main" > /etc/apt/sources.list.d/llvm.list \
  && apt-get update && apt-get install -y clang-4.0 lldb-4.0 \
  && rm -rf /var/lib/apt/lists/*

# make Clang 4.0 the default compiler
RUN update-alternatives --install /usr/bin/cc cc /usr/bin/clang-4.0 100 \
  && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-4.0 100

# pull iqtree2 source and respective submodules
WORKDIR ${SRC_DIR}
RUN git clone https://github.com/iqtree/iqtree2.git --branch v2.2.3 . \
  && git submodule update --init --recursive

# compile and install iqtree2 binary
WORKDIR ${SRC_DIR}/build
RUN cmake .. \
  && make -j ${N_PROCS} \
  && make install \
  && cd .. \
  && rm -r build

# compile and install iqtree2-mpi binary
WORKDIR ${SRC_DIR}/build-mpi
RUN cmake -DIQTREE_FLAGS=mpi -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx .. \
  && make -j ${N_PROCS} \
  && make install \
  && cd .. \
  && rm -r build-mpi

# installation process installs unnecessary example files to /usr/local
WORKDIR /usr/local
RUN rm models.nex example.phy example.nex example.cf

WORKDIR /home/experiments
CMD ["/bin/bash"]
