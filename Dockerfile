FROM debian:bookworm-slim AS chktex
WORKDIR /tmp/workdir
RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends g++ make perl wget libncurses5-dev ca-certificates && \
    update-ca-certificates
ARG CHKTEX_VERSION=1.7.10
RUN wget -O chktex-${CHKTEX_VERSION}.tar.gz http://download.savannah.gnu.org/releases/chktex/chktex-${CHKTEX_VERSION}.tar.gz
RUN tar -xz --strip-components=1 -f chktex-${CHKTEX_VERSION}.tar.gz
RUN ./configure && \
    make && \
    mv chktex /tmp && \
    rm -r *


FROM debian:bookworm-slim AS ltexls
WORKDIR /tmp/workdir
RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends ca-certificates curl tar ca-certificates && \
    update-ca-certificates
ARG LTEX_VERSION=16.0.0
RUN curl -o "/tmp/ltex-ls-${LTEX_VERSION}.tar.gz" -L "https://github.com/valentjn/ltex-ls/releases/download/${LTEX_VERSION}/ltex-ls-${LTEX_VERSION}.tar.gz" && \
    mkdir -p /usr/share && \
    tar -xf /tmp/ltex-ls-${LTEX_VERSION}.tar.gz -C /usr/share && \
    rm -f /tmp/ltex-ls-${LTEX_VERSION}.tar.gz && \
    mv /usr/share/ltex-ls-${LTEX_VERSION} /usr/share/ltex-ls


FROM debian:bookworm-slim
ENV USER_ID=1000
ENV GROUP_ID=1000
ENV USER_NAME=container-user
ENV GROUP_NAME=container-user

RUN addgroup --gid $GROUP_ID $GROUP_NAME && \
    adduser --shell /bin/bash --disabled-password \
    --uid $USER_ID --ingroup $GROUP_NAME $USER_NAME 

# Ensure /home/container-user is owned by container-user
RUN mkdir -p /home/container-user/.vscode-server && \
    chown -R $USER_NAME:$GROUP_NAME /home/container-user

RUN mkdir -p /home/container-user/project && \
    chown -R $USER_NAME:$GROUP_NAME /home/container-user
    
RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    ca-certificates \
    cpanminus \
    curl \
    default-jre \
    gcc \
    git \
    inkscape \
    libc6-dev \
    make \
    perl \
    tar \
    wget && \
    update-ca-certificates

USER $USER_NAME
# TEXLIVE

WORKDIR /tmp/texlive
ARG TEX_SCHEME=small
RUN wget -qO- https://ctan.mirror.cherryfox.dev/systems/texlive/tlnet/install-tl-unx.tar.gz | tar -xz --strip-components=1 && \
    perl install-tl --paper=a4 --scheme=${TEX_SCHEME} --no-doc-install --no-src-install --texdir=/usr/local/texlive --no-interaction && \
    rm -rf /usr/local/texlive/*.log /usr/local/texlive/texmf-var/web2c/*.log /usr/local/texlive/tlpkg/texlive.tlpdb.main.*
ENV PATH ${PATH}:/usr/local/texlive/bin/x86_64-linux:/usr/local/texlive/bin/aarch64-linux
# LATEXINDENT & LATEXMK
RUN cpanm -n -q Log::Log4perl && \
    cpanm -n -q XString && \
    cpanm -n -q Log::Dispatch::File && \
    cpanm -n -q YAML::Tiny && \
    cpanm -n -q File::HomeDir && \
    cpanm -n -q Unicode::GCString && \
    cpanm -n -q Encode
RUN tlmgr install latexindent latexmk && texhash
# LTEX-LS
COPY --from=ltexls /usr/share/ltex-ls /usr/share/ltex-ls
# CHKTEX
COPY --from=chktex /tmp/chktex /usr/local/bin/chktex
# CLEANUP
RUN rm -rf /tmp/texlive && \
    sudo apt-get remove -y cpanminus make gcc libc6-dev && \
    sudo apt-get clean autoclean && \
    sudo apt-get autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/
WORKDIR /workspace
