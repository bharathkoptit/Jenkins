#!/bin/bash

# Clean up the specified directories
echo "Cleaning up /var/tmp and /var/cache..."
rm -rf /var/tmp/*
rm -rf /var/cache/*

# Clean up Jenkins workspace - delete all subfolders and files
echo "Cleaning up Jenkins workspace..."
JENKINS_WORKSPACE="/var/lib/jenkins/workspace"
echo "Deleting all contents under $JENKINS_WORKSPACE..."
rm -rf "$JENKINS_WORKSPACE"/*

# Clean up Jenkins jobs - keep only the latest build and logs in each job folder
echo "Cleaning up Jenkins jobs, keeping only the latest build and logs..."
JENKINS_JOBS_DIR="/var/lib/jenkins/jobs"
for job in "$JENKINS_JOBS_DIR"/*/; do
    if [ -d "$job/builds" ]; then
        builds=$(ls -dt "$job/builds"/*/ | tail -n +2)
        echo "Deleting builds in $job except the latest one..."
        for build in $builds; do
            rm -rf "$build"
        done
    fi
    if [ -d "$job/logs" ]; then
        logs=$(ls -dt "$job/logs"/* | tail -n +2)
        echo "Deleting logs in $job except the latest one..."
        for log in $logs; do
            rm -rf "$log"
        done
    fi
done

# Clean up Jenkins backups - keep only the latest backup
echo "Cleaning up Jenkins backups, keeping only the latest one..."
BACKUP_DIR="/var/lib/jenkins/s3:/optitjenkinsbackup"
latest_backup=$(ls -dt "$BACKUP_DIR"/FULL-* | head -n 1)
backups_to_delete=$(ls -dt "$BACKUP_DIR"/FULL-* | tail -n +2)
echo "Deleting old backups..."
for backup in $backups_to_delete; do
    rm -rf "$backup"
done

# Clean up unused Docker images
echo "Cleaning up unused Docker images..."
docker image prune -af

# Clean up unused Docker containers
echo "Cleaning up unused Docker containers..."
docker container prune -f

echo "Clean-up process completed."
