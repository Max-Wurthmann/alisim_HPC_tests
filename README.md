# HPC Simulation of Sequence evolution

This repository is part of an effort to reproduce the results of Ly-Trong et al. (2023).

## Content

- `run.sh` and `run_manual.sh`: shell scripts to be executed in the docker container that run experiments
- `Dockerfile`: used to create the virtual environment that has IQ-TREE2 v2.2.3 installed, meaning both `iqtree2` and `iqtree2-mpi` are available.
- `generate_figures.ipynb`: plot and summerize the generated data
- `experiments`: folder containing experiment data
- `figures`: folder containing generated figures

## Usage notes

### Usage of Docker

The Dockerfile is set up such that building the Dockerfile into a Docker image automatically performs the following steps:

1. Install all dependencies
2. Fetch source code for IQ-Tree2 v2.2.3 from GitHub
3. Compile `iqtree2` and `iqtree2-mpi` binaries from source
4. Install `iqtree2` and `iqtree2-mpi` binaries to `/usr/local/bin/`

Thus, when running the Docker image as a container, the binaries are immediately accessible.

To build the Docker image from the Dockerfile, download the Dockerfile, and with the Dockerfile in the current working directory run:

```bash
docker build -t iqtree:latest .
````

The created image is called `iqtree:latest`, and we can start a container called `ciqtree` from that image as follows:

```bash
docker run -it --name ciqtree iqtree:latest
```

The above command also opens an interactive shell into the container.

Explicitly stopping the container can be done via:

```bash
docker stop ciqtree
```

While restarting the container and opening an interactive shell into it can be done with:

```bash
docker start -ai ciqtree
```

To open another shell into a running container, use:

```bash
docker exec -it ciqtree bash
```

### Usage of AliSim-HPC

I will give a brief overview of the commands and options used for the experiments.
For a complete overview of the functionality of AliSim please refer to the [AliSim wiki page](https://github.com/iqtree/iqtree2/wiki/AliSim).

Example Commands:

```bash
# without MPI
iqtree2 --alisim output/alg -m GTR+I{0.2}+G4{0.5} --length 200000 \
  --num-alignments 48 -r 6000 -nt 4 --openmp-alg IM

# with MPI
mpirun -np 4 --allow-run-as-root iqtree2-mpi --alisim [...]
```

*AliSim command options were opitted in the MPI version for brevity. They are the same.*

- `iqtree2`: The name of the non-MPI executable. The `--alisim` option tells it that we want to use the AliSim software.
- `output/alg`: All generated assets are saved in the directory `output` (should previously exist) and are prefixed with `alg`.
- `-m GTR+I{0.2}+G4{0.5}`: Define substitution model as **GTR** with a proportion of invariant sites of 0.2 and a discrete gamma model of rate heterogeneity with 4 rates and a shape parameter of 0.5 (used for experiments following AliSim-HPC).
- `--length 200000`: The generated sequences have 200,000 sites (`n_sites = 200000`).
- `--num-alignments 48`: For the given phylogeny, 48 alignments are generated separately (`n_alg = 48`).
- `-r 6000`: Instead of providing a phylogeny (e.g., with the `-t` option), a random tree with 6000 taxa (`n_taxa = 6000`) is generated under the Yule–Harding model.
- `-nt 4 --openmp-alg IM`: OpenMP parallelism is used with 4 threads per process. The algorithm can be either the internal memory variant **OpenMP-IM** or the external memory variant **OpenMP-EM**.
- `mpirun [mpi options] iqtree2-mpi --alisim [alisim options]`: When using MPI parallelism, the structure of the command changes because the command must be passed to `mpirun` instead of running directly from the shell. Additionally, the executable must be `iqtree2-mpi` instead of `iqtree2`.
- `-np 4 --allow-run-as-root`: MPI options that set the number of processes to 4 and allow running as root. Running MPI as root is not recommended in general, but inside a Docker container it is acceptable and useful.

## References

- N. Ly-Trong, G.M.J. Barca, B.Q. Minh (2023) AliSim-HPC: parallel sequence simulator for phylogenetics. Bioinformatics, 39:btad540. <https://doi.org/10.1093/bioinformatics/btad540>
