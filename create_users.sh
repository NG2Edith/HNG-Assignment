#!/bin/bash

# Script to create users and groups from a given text file
# Usage: bash create_users.sh <name-of-text-file>
# Example: bash create_users.sh users.txt

# Log file
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Check if the input file is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

INPUT_FILE=$1

# Ensure the log and password files exist
touch $LOG_FILE
mkdir -p /var/secure
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

log_action() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

create_user() {
  local username=$1
  local groups=$2

  # Create the user's personal group
  if ! getent group $username > /dev/null 2>&1; then
    groupadd $username
    log_action "Created group $username"
  else
    log_action "Group $username already exists"
  fi

  # Create user
  if ! id -u $username > /dev/null 2>&1; then
    useradd -m -g $username -s /bin/bash $username
    log_action "Created user $username"
  else
    log_action "User $username already exists"
    return
  fi

  # Assign additional groups to the user
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo $group | xargs) # Remove leading/trailing whitespaces
    if ! getent group $group > /dev/null 2>&1; then
      groupadd $group
      log_action "Created group $group"
    fi
    usermod -aG $group $username
    log_action "Added user $username to group $group"
  done

  # Generate a random password for the user
  local password=$(openssl rand -base64 12)
  echo "$username:$password" | chpasswd
  log_action "Set password for user $username"

  # Store the password securely
  echo "$username,$password" >> $PASSWORD_FILE
}

while IFS=';' read -r username groups; do
  username=$(echo $username | xargs) # Remove leading/trailing whitespaces
  groups=$(echo $groups | xargs)     # Remove leading/trailing whitespaces
  create_user $username "$groups"
done < $INPUT_FILE

log_action "User creation script completed"

