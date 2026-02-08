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


echo -e "\n###### Python user software update ######\n"

# Fetch outdated packages in JSON format
OUTDATED_JSON=$(pip3 list --user --outdated --format=json)

# Check if there are any outdated packages
if [ "$OUTDATED_JSON" == "[]" ] || [ -z "$OUTDATED_JSON" ]; then
    echo "[INFO] All user python packages are up to date."
    exit 0
fi

# Iterate through each item in the JSON array
echo "$OUTDATED_JSON" | jq -c '.[]' | while read -r pkg; do
    name=$(echo "$pkg" | jq -r '.name')
    current=$(echo "$pkg" | jq -r '.version')
    latest=$(echo "$pkg" | jq -r '.latest_version')

    echo "-------------------------------------------------------"
    echo "[INFO] Package: ${name}"
    echo "[INFO] Current: ${current} -> Latest: ${latest}"

    # On Pop!_OS, we add the break flag to allow --user installs to proceed
    if ! pip3 install --user -U "${name}" --break-system-packages; then
        echo "❌ ERROR: Update failed for ${name}!"
        exit 1
    else
        echo "✅ Success: ${name} updated"
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

