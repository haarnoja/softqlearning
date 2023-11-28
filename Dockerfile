FROM ubuntu:16.04


# ========== Anaconda ==========
# https://github.com/ContinuumIO/docker-images/blob/master/anaconda/Dockerfile
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

SHELL ["/bin/bash", "-c"]

RUN apt-get update --fix-missing && apt-get install -y wget bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git mercurial subversion

RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/archive/Anaconda2-5.0.1-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh

RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://api.github.com/repos/krallin/tini/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'` && \
    curl -L "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini_${TINI_VERSION:1}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean

ENV PATH /opt/conda/bin:$PATH


# ========== Special Deps ==========
RUN apt-get -y install git make cmake unzip
RUN pip install awscli
# ALE requires zlib
RUN apt-get -y install zlib1g-dev
# MUJOCO requires graphics stuff (Why?)
RUN cp /etc/apt/sources.list /etc/apt/sources.list~ \
    && sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list \
    && apt-get update
RUN apt-get -y build-dep glfw
RUN apt-get -y install libxrandr2 libxinerama-dev libxi6 libxcursor-dev
RUN apt-get install -y vim ack-grep
RUN pip install --upgrade pip
# usual pip install pygame will fail
RUN apt-get build-dep -y python-pygame
RUN pip install Pillow


# ========== Add codebase stub ==========
WORKDIR /root/sql

ADD environment.yml /root/sql/environment.yml
RUN pip install --upgrade requests
RUN conda env create -f /root/sql/environment.yml \
    && conda env update

ENV PYTHONPATH /root/sql:$PYTHONPATH
ENV PATH /opt/conda/envs/sql/bin:$PATH
RUN echo "source activate sql" >> /root/.bashrc
ENV BASH_ENV /root/.bashrc


# ========= rllab ===============
# We need to clone rllab repo in order to use the
# `rllab.sandbox.rocky.tf` functions.

ENV RLLAB_PATH=/root/rllab \
    RLLAB_VERSION=b3a28992eca103cab3cb58363dd7a4bb07f250a0

RUN git clone https://github.com/rll/rllab.git ${RLLAB_PATH} \
    && cd ${RLLAB_PATH} \
    && git checkout ${RLLAB_VERSION} \
    && mkdir ${RLLAB_PATH}/vendor/mujoco \
    && python -m rllab.config

ENV PYTHONPATH ${RLLAB_PATH}:${PYTHONPATH}


# ========= MuJoCo ===============
ENV MUJOCO_VERSION=1.3.1 \
    MUJOCO_PATH=/root/.mujoco

RUN MUJOCO_ZIP="mjpro$(echo ${MUJOCO_VERSION} | sed -e "s/\.//g")_linux.zip" \
    && mkdir -p ${MUJOCO_PATH} \
    && wget -P ${MUJOCO_PATH} https://www.roboti.us/download/${MUJOCO_ZIP} \
    && unzip ${MUJOCO_PATH}/${MUJOCO_ZIP} -d ${MUJOCO_PATH} \
    && cp ${MUJOCO_PATH}/mjpro131/bin/libmujoco131.so ${RLLAB_PATH}/vendor/mujoco/ \
    && cp ${MUJOCO_PATH}/mjpro131/bin/libglfw.so.3 ${RLLAB_PATH}/vendor/mujoco/ \
    && rm ${MUJOCO_PATH}/${MUJOCO_ZIP}

# ========== Package Patches ==========

RUN source activate sql && pip install "numpy>=1.16"
