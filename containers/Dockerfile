FROM quay.io/jupyter/base-notebook:latest

USER root

RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends git libgdal-dev libgeos-dev libproj-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=${NB_UID} environment.yml /tmp/environment.yml

ENV PIP_NO_CACHE_DIR=1

RUN mamba env create -f /tmp/environment.yml && \
    mamba clean --all -y -f && \
    rm /tmp/environment.yml && \
    fix-permissions /opt/conda/envs/notebook && \
    fix-permissions /home/jovyan

RUN /opt/conda/envs/notebook/bin/python -m ipykernel install \
    --prefix=/opt/conda \
    --name="notebook" \
    --display-name="Python (notebook)" && \
    ls /opt/conda/share/jupyter/kernels/

RUN mkdir -p /home/jovyan/.ipython && \
    fix-permissions /home/jovyan/.ipython

USER ${NB_USER}
