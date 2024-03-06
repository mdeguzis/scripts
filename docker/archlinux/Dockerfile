# vim: ft=Dockerfile

FROM archlinux:base-devel

# Update
RUN pacman -Syyu --noconfirm

# Base packages
RUN pacman -S --noconfirm \
    base-devel \
    flatpak \
    jq \
    git \
    vim

# Flatpak config
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
