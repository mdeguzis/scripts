#!/bin/bash -x

# Need this or you will get errors on install/run with "Could not connect"
echo "Enabling dbus-daemon"
sudo dbus-daemon --system

echo "Adding Flathub remote for user"
flatpak --user --if-not-exists remote-add flathub https://flathub.org/repo/flathub.flatpakrepo
