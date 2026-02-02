#!/bin/bash

# Configuration
REPO_URL="https://github.com/FredHutch/tb_pacts_tools.git"
REPO_NAME="tb_pacts_tools"
HACKDAY_REPO_URL="https://github.com/agartland/hackday-rstudio.git"
HACKDAY_REPO_NAME="hackday-rstudio"
ROSTER_FILE="/home/seatrac-hackday-2026/roster.users.csv"
TEMP_CLONE_DIR="/tmp/${REPO_NAME}"

echo "Starting student repository setup..."

# Step 0: Checkout/update the repos in /home (root access only)
echo "Setting up source repositories in /home..."
cd /home

# Clone or update hackday-rstudio
if [ -d "${HACKDAY_REPO_NAME}" ]; then
    echo "Updating existing ${HACKDAY_REPO_NAME} repository..."
    cd "${HACKDAY_REPO_NAME}"
    git pull || echo "Warning: Could not pull ${HACKDAY_REPO_NAME}, continuing with existing version"
    cd /home
else
    echo "Cloning ${HACKDAY_REPO_NAME} repository..."
    git clone "${HACKDAY_REPO_URL}" || { echo "Error: Failed to clone ${HACKDAY_REPO_NAME}"; exit 1; }
fi

# Clone or update tb_pacts_tools
if [ -d "${REPO_NAME}" ]; then
    echo "Updating existing ${REPO_NAME} repository..."
    cd "${REPO_NAME}"
    git pull || echo "Warning: Could not pull ${REPO_NAME}, continuing with existing version"
    cd /home
else
    echo "Cloning ${REPO_NAME} repository..."
    git clone "${REPO_URL}" || { echo "Error: Failed to clone ${REPO_NAME}"; exit 1; }
fi

# Step 1: Clone/update the repository to a temporary location for distribution
echo "Preparing repository for distribution from ${REPO_URL}..."
cd /tmp

if [ -d "${TEMP_CLONE_DIR}" ]; then
    echo "Updating existing temporary clone..."
    cd "${TEMP_CLONE_DIR}"
    git pull || { echo "Warning: Could not pull temp repo, removing and recloning..."; cd /tmp; rm -rf "${TEMP_CLONE_DIR}"; git clone "${REPO_URL}" "${TEMP_CLONE_DIR}"; }
    cd /tmp
else
    git clone "${REPO_URL}" "${TEMP_CLONE_DIR}" || { echo "Error: Failed to clone to temp location"; exit 1; }
fi

# Step 2: Create users from roster (if they don't exist)
echo "Creating users from roster..."
if [ ! -f "${ROSTER_FILE}" ]; then
    echo "Error: Roster file not found at ${ROSTER_FILE}"
    exit 1
fi

cd /home
python3 hackday-rstudio/create_users.py "${ROSTER_FILE}" || echo "Warning: User creation had issues, continuing..."

# Step 3: Display created users
echo "Verifying users in /etc/passwd..."
tail -5 /etc/passwd  # Just show last 5 to avoid clutter

# Step 4: Copy PAM configuration
echo "Copying PAM configuration..."
if [ ! -f /etc/pam.d/rstudio ]; then
    cp /etc/pam.d/login /etc/pam.d/rstudio
    echo "  ✓ PAM configuration copied"
else
    echo "  ✓ PAM configuration already exists"
fi

# Step 5: Create shared folder
echo "Creating shared folder at /home/shared..."
SHARED_DIR="/home/shared"
mkdir -p "${SHARED_DIR}"
chmod 777 "${SHARED_DIR}"
echo "  ✓ Shared folder created/verified with read/write access for all users"

# Step 6: Copy repository to each user's home directory
echo "Copying repository to user home directories..."

# Check if roster file exists and is readable
if [ ! -r "${ROSTER_FILE}" ]; then
    echo "Error: Cannot read roster file at ${ROSTER_FILE}"
    exit 1
fi

# Count successful and failed copies
success_count=0
fail_count=0

# Read usernames from the roster CSV (assuming username is in first column, skip header)
tail -n +2 "${ROSTER_FILE}" | while IFS=, read -r username rest; do
    # Remove any whitespace, quotes, and carriage returns
    username=$(echo "${username}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' | tr -d '\r\n')
    
    # Skip empty lines
    if [ -z "${username}" ]; then
        continue
    fi
    
    USER_HOME="/home/${username}"
    
    # Check if user home directory exists
    if [ ! -d "${USER_HOME}" ]; then
        echo "  ✗ Warning: Home directory not found for user ${username}"
        fail_count=$((fail_count + 1))
        continue
    fi
    
    echo "Processing user: ${username}"
    
    # Copy repository to user's home directory
    TARGET_DIR="${USER_HOME}/${REPO_NAME}"
    
    # Remove existing repo if present
    if [ -d "${TARGET_DIR}" ]; then
        echo "  Removing existing repository in ${TARGET_DIR}..."
        rm -rf "${TARGET_DIR}"
    fi
    
    # Copy the repository
    echo "  Copying repository to ${TARGET_DIR}..."
    if cp -r "${TEMP_CLONE_DIR}" "${TARGET_DIR}"; then
        # Set ownership and permissions
        chown -R "${username}:${username}" "${TARGET_DIR}"
        chmod -R u+rw "${TARGET_DIR}"
        
        # Create adata folder in user's home directory
        ADATA_DIR="${USER_HOME}/adata"
        mkdir -p "${ADATA_DIR}"
        chown "${username}:${username}" "${ADATA_DIR}"
        chmod 755 "${ADATA_DIR}"
        
        echo "  ✓ Completed for ${username}"
        success_count=$((success_count + 1))
    else
        echo "  ✗ Failed to copy repository for ${username}"
        fail_count=$((fail_count + 1))
    fi
done

# Step 7: Cleanup
echo "Cleaning up temporary files..."
rm -rf "${TEMP_CLONE_DIR}"

echo ""
echo "========================================="
echo "Setup complete!"
echo "Repository has been copied to all user home directories with proper permissions."
echo "Each user has an 'adata' folder in their home directory."
echo "A shared folder is available at /home/shared with read/write access for all users."
echo "========================================="