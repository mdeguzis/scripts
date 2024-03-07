# vim: ft=Dockerfile

FROM archlinux:base-devel

# Args to pass in
ARG HOST_USER
ARG UID=1000
ARG GID=1000

# Env vars
ENV USER ${HOST_USER}
ENV HOME /home/${USER}

# Update
RUN pacman -Syyu --noconfirm

# Base packages
RUN pacman -S --noconfirm \
    base-devel \
    flatpak \
    git \
    jq \
    unzip \
    vim

# Add non-root user
# Create user and setup permissions on /etc/sudoers
RUN echo "Creating user ${USER} and adding to sudoers"
RUN groupadd -g ${GID} devusers
RUN useradd --uid $UID --gid $GID --shell /bin/bash --create-home $USER
RUN echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
    chmod 440 /etc/sudoers && \
    chmod g+w /etc/passwd


USER ${USER}
WORKDIR ${HOME}

COPY init.sh /init.sh
ENTRYPOINT ["/bin/bash", "/init.sh"]
CMD /bin/bash

