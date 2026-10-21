FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gcc g++ make perl \
        python3 python3-setuptools python3-pip python3-ply python3-docutils \
        python3-pyelftools python3-dev \
        git subversion curl wget ca-certificates rsync unzip zip p7zip-full \
        xz-utils zstd bzip2 \
        bc bison flex gperf gawk gettext \
        libncurses-dev libssl-dev libelf-dev zlib1g-dev liblzma-dev libbz2-dev \
        libreadline-dev libgmp-dev libmpc-dev libmpfr-dev \
        libtool automake autoconf pkg-config \
        cpio file time patch diffstat quilt ccache \
        device-tree-compiler lrzsz nano vim-common tar findutils which sudo \
        swig intltool help2man re2c scons \
        genisoimage dosfstools e2fsprogs fdisk parted util-linux \
        qemu-utils btrfs-progs squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && (apt-get install -y --no-install-recommends ack antlr3 asciidoc ecj fastjar upx-ucl lld llvm clang xmlto || true) \
    && rm -rf /var/lib/apt/lists/*

VOLUME ["/build"]
WORKDIR /build
CMD ["/bin/bash"]