#!/bin/bash

# Set the source directory (Jenkins jobs directory)
SOURCE_DIR="/var/lib/jenkins/jobs"

# Set the base destination directory for the backup
BASE_DEST_DIR="/var/lib/jenkins/jenkins_backup"

# Create a timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Set the full destination directory including the timestamp
DEST_DIR="$BASE_DEST_DIR/backup_$TIMESTAMP"

# Create the backup directory
mkdir -p "$DEST_DIR"

# Use rsync to copy the directory structure and config.xml files
rsync -av --include '*/' --include 'config.xml' --exclude '*' "$SOURCE_DIR/" "$DEST_DIR/"

# Create a zip file of the backup directory
zip -r "${DEST_DIR}.zip" "$DEST_DIR"

# Remove the unzipped backup directory to save space
rm -rf "$DEST_DIR"

# Log the backup operation
echo "$(date) - Backup completed to ${DEST_DIR}.zip" >> "$BASE_DEST_DIR/backup.log"
