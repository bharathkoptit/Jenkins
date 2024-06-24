#!/bin/bash

# Jenkins home directory path
JENKINS_HOME="/var/lib/jenkins"

# S3 bucket name
YOUR_BUCKET_NAME="optitjenkinsbackup"

# Tar the Jenkins home directory
echo "Tarring $JENKINS_HOME directory"
tar -cvf jenkins_backup.tar -C $JENKINS_HOME .

# Check the exit code of the tar command
exitcode=$?
if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
    exit $exitcode
fi

# Upload the tarred file to S3 bucket
echo "Uploading jenkins_backup.tar to S3 bucket"
aws s3 cp jenkins_backup.tar s3://$YOUR_BUCKET_NAME/

# Remove files after successful upload to S3
echo "Removing files after successful upload to S3"
rm -rf jenkins_backup.tar
