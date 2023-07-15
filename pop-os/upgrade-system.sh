#!/bin/bash
# Upgrades system fully via CLI
# See: https://support.system76.com/articles/upgrade-pop/

echo "--------------------------------"
echo "Updating software lists..."
echo -e "--------------------------------\n"
sleep 2s

if ! sudo apt-get update; then
    echo "ERROR: update failed!"
    exit 1
fi

echo -e "\n--------------------------------"
echo "Upgrading software..."
echo -e "--------------------------------\n"
sleep 2s

echo "##### System software update ######"
if ! sudo apt-get full-upgrade -y --allow-downgrades; then
    echo "ERROR: Apt upgrade failed!"
    exit 1
fi

echo -e "\n###### Flatpak software update ###### "
if ! flatpak update -y; then
    echo "ERROR: Flatpak upgrade failed!"
    exit 1
fi

echo -e "\n###### Python user software update ######"
for x in $(pip3 list --user --outdated --format=freeze \
        | grep -v '^\-e' \
        | cut -d = -f 1); 
    do
        if ! sudo pip3 install -U ${x} --ignore-installed; then
            echo "ERROR: Pip upgrade failed for ${x}!"
            exit 1
        fi
    done

echo -e "\n--------------------------------"
echo "Running pop-upgrade..."
echo -e "--------------------------------\n"
sleep 2s

if pop-upgrade release upgrade; then
    echo "Cleaning up..."
    sudo apt-get autoremove -y
else
    echo "ERROR: pop-upgrade failed!"
    exit 1
fi

