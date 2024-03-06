# vim: ft=Dockerfile

FROM archlinux:base-devel

# Args to pass in
ARG HOST_USER

# Env vars
ENV USER ${HOST_USER}
ENV HOME /home/${USER}

# Update
RUN pacman -Syyu --noconfirm

# Base packages
RUN pacman -S --noconfirm \
    base-devel \
    flatpak \
    jq \
    git \
    vim

# Add non-root user
# Create user and setup permissions on /etc/sudoers
RUN echo "Creating user ${USER} and adding to sudoers"
RUN useradd --gid users --shell /bin/bash --create-home ${USER}
RUN echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
    chmod 440 /etc/sudoers && \
    chmod g+w /etc/passwd

# Flatpak config
RUN flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

USER ${USER}
WORKDIR ${HOME}
