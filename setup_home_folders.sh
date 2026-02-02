#!/bin/bash

# Exit on any error
set -e

# Configuration
REPO_URL="https://github.com/FredHutch/tb_pacts_tools.git"
REPO_NAME="tb_pacts_tools"
ROSTER_FILE="/home/seatrac-hackday-2026/roster.users.csv"
TEMP_CLONE_DIR="/tmp/${REPO_NAME}"

echo "Starting student repository setup..."

# Step 0: Checkout the repos to a location that only root can access
cd /home
git clone https://github.com/agartland/seatrac-hackday-2026.git
git clone https://github.com/agartland/hackday-rstudio.git
git clone https://github.com/FredHutch/tb_pacts_tools.git

# Step 1: Clone the repository to a temporary location
echo "Cloning repository from ${REPO_URL}..."
cd /tmp
if [ -d "${TEMP_CLONE_DIR}" ]; then
    echo "Removing existing temporary clone..."
    rm -rf "${TEMP_CLONE_DIR}"
fi
git clone "${REPO_URL}" "${TEMP_CLONE_DIR}"

# Step 2: Create users from roster
echo "Creating users from roster..."
cd /home
python3 hackday-rstudio/create_users.py "${ROSTER_FILE}"

# Step 3: Display created users
echo "Verifying users in /etc/passwd..."
cat /etc/passwd

# Step 4: Copy PAM configuration
echo "Copying PAM configuration..."
cp /etc/pam.d/login /etc/pam.d/rstudio

# Step 5: Create shared folder
echo "Creating shared folder at /home/shared..."
SHARED_DIR="/home/shared"
if [ ! -d "${SHARED_DIR}" ]; then
    mkdir -p "${SHARED_DIR}"
fi
# Set permissions so everyone can read/write
chmod 777 "${SHARED_DIR}"
# Set sticky bit so users can only delete their own files
# chmod +t "${SHARED_DIR}"
echo "  ✓ Shared folder created with read/write access for all users"

# Step 6: Copy repository to each user's home directory
echo "Copying repository to user home directories..."

# Read usernames from the roster CSV (assuming username is in first column, skip header)
tail -n +2 "${ROSTER_FILE}" | while IFS=, read -r username rest; do
    # Remove any whitespace or quotes
    username=$(echo "${username}" | tr -d ' "' | tr -d '\r')
    
    # Skip empty lines
    if [ -z "${username}" ]; then
        continue
    fi
    
    USER_HOME="/home/${username}"
    
    # Check if user home directory exists
    if [ -d "${USER_HOME}" ]; then
        #echo "Processing user: ${username}"
        
        # Copy repository to user's home directory
        TARGET_DIR="${USER_HOME}/${REPO_NAME}"
        
        # Remove existing repo if present
        if [ -d "${TARGET_DIR}" ]; then
            #echo "  Removing existing repository in ${TARGET_DIR}..."
            rm -rf "${TARGET_DIR}"
        fi
        
        # Copy the repository
        #echo "  Copying repository to ${TARGET_DIR}..."
        cp -r "${TEMP_CLONE_DIR}" "${TARGET_DIR}"
        
        # Set ownership and permissions
        #echo "  Setting ownership and permissions..."
        chown -R "${username}:${username}" "${TARGET_DIR}"
        chmod -R u+rw "${TARGET_DIR}"
        
        # Create adata folder in user's home directory
        ADATA_DIR="${USER_HOME}/adata"
        if [ ! -d "${ADATA_DIR}" ]; then
            #echo "  Creating adata folder..."
            mkdir -p "${ADATA_DIR}"
            chown "${username}:${username}" "${ADATA_DIR}"
            chmod 755 "${ADATA_DIR}"
        fi
        
        echo "  ✓ Completed for ${username}"
    else
        echo "  ✗ Warning: Home directory not found for user ${username}"
    fi
done

# Step 7: Cleanup
echo "Cleaning up temporary files..."
rm -rf "${TEMP_CLONE_DIR}"

echo "Setup complete!"
echo "Repository has been copied to all user home directories with proper permissions."
echo "Each user has an 'adata' folder in their home directory."
echo "A shared folder is available at /home/shared with read/write access for all users."