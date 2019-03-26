#!/bin/bash

set -Eeuo pipefail

CONFIG_VARS=(REPO_DIR PW_FILE BACKUP_NAME BACKUP_LIST BORG_CREATE_OPTIONS BORG_PRUNE_OPTIONS PWGEN_CMD BORG_INIT_CMD BORG_PASSCOMMAND REPO_SYNC_COMMAND)

print_info() {
  local GREEN='\033[0;32m'
  local NC='\033[0m'
  local MSG="$1"
  if [ -t 1 ]; then
    echo -e "${GREEN}[INFO]${NC} ${MSG}"
  else
    echo "[INFO] ${MSG}"
  fi
}

print_err() {
  local RED='\033[0;31m'
  local NC='\033[0m'
  local MSG="$1"
  if [ -t 1 ]; then
    echo -e "${RED}[ERROR]${NC} ${MSG}"
  else
    echo "[ERROR] ${MSG}"
  fi
}

print_warn() {
  local YELLOW='\033[0;33m'
  local NC='\033[0m'
  local MSG="$1"
  if [ -t 1 ]; then
    echo -e "${YELLOW}[WARN]${NC} ${MSG}"
  else
    echo "[ERROR] ${MSG}"
  fi
}

check_dependencies() {
  command -v borg > /dev/null 2>&1 || { print_err "You need borg to use this utility."; exit 1; }
  command -v pwgen > /dev/null 2>&1 || { print_err "You need pwgen to use this utility."; exit 1; }
}

load_config() {
  SCRIPT_DIR="$(dirname "$BASH_SOURCE")"
  if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -o allexport
    source .env
    set +o allexport
  else
    print_err "You must configure this script via a .env file."
    exit 1
  fi
}

check_var() {
  local VAR_NAME="$1"
  if [ -z "${!VAR_NAME}" ]; then
    print_err "Configuration error: ${VAR_NAME} needs to be set."
    exit 1
  fi
}

check_config() {
  set +u
  for i in "${CONFIG_VARS[@]}"; do
    check_var "$i"
  done
  set -u
}

generate_password() {
  print_info "Password file doesn't exists at ${PW_FILE}, generating..."
  PW_DIR="$(dirname "${PW_FILE}")"
  mkdir -p "${PW_DIR}"
  chmod 0700 "${PW_DIR}"
  if ${PWGEN_CMD} > "${PW_FILE}"; then
    print_info "Password successfully generated to ${PW_FILE}."
  else
    print_err "Failed to generate password. Aborting."
    exit 1
  fi
  chmod 0400 "${PW_FILE}"
  print_warn "Password has been generated to ${PW_FILE}. You might want to save it in a password manager."
}

init_repo() {
  print_info "Borg repo doesn't exists at ${REPO_DIR}, creating..."
  mkdir -p "${REPO_DIR}"
  chmod 0700 "${REPO_DIR}"
  if ${BORG_INIT_CMD}; then
    print_info "Borg repo has been created in ${REPO_DIR} using keyfile encryption."
    print_warn "You might want to backup the repo key in a password manager: \`borg key export ${REPO_DIR} <file>\`."
  else
    print_err "Failed to create borg repository in ${REPO_DIR}. Aborting."
    exit 1
  fi
}

borg_backup() {
  local BACKUP_NAME="$1"
  print_info "Creating backup ${BACKUP_NAME} with borg..."
  if borg create ${BORG_CREATE_OPTIONS} "${REPO_DIR}::${BACKUP_NAME}" ${BACKUP_LIST}; then
    print_info "Backup has been created successfully."
  else
    print_err "Failed to create backup with borg. Aborting."
    exit 1
  fi
}

sync_repo() {
  print_info "Syncing borg repo to remote storage..."
  if ${REPO_SYNC_COMMAND}; then
    print_info "Backup repository has been synced to remote storage successfully."
  else
    print_err "Failed to sync backup repository to remote storage. Aborting."
    exit 1
  fi
}

borg_list() {
  if [ "$#" -gt 0 ]; then
    print_info "Listing contents of backup \"$1\"..."
    borg list "${REPO_DIR}"::"$1"
  else
    print_info "Listing backups..."
    borg list "${REPO_DIR}"
  fi
}

borg_delete() {
  local BACKUP_NAME=$1
  print_info "Deleting backup ${BACKUP_NAME} from repo ${REPO_DIR}"
  borg delete --stats "${REPO_DIR}::${BACKUP_NAME}"
}

borg_info() {
  if [ "$#" -gt 0 ]; then
    borg info "${REPO_DIR}"::"$1"
  else
    borg info "${REPO_DIR}"
  fi
}

borg_prune() {
  print_info "Pruning backups..."
  if borg prune ${BORG_PRUNE_OPTIONS} "${REPO_DIR}"; then
    print_info "Backup repository has been pruned."
  else
    print_err "Failed to prune backups. Aborting."
    exit 1
  fi  
}

borg_check() {
  print_info "Checking backup repository for corruption..."
  if borg check --verify-data "${REPO_DIR}"; then
    print_info "Backup repository has been checked, no errors found."
  else
    print_err "Backup repository seems to be corrupted."
    exit 1
  fi  
}

borg_mount() {
  local BORG_MOUNT_POINT="$1"
  print_info "Mounting backup in foreground... Press CTRL+C to unmount the repository."
  borg mount --foreground "${REPO_DIR}" "${BORG_MOUNT_POINT}"
}

borg_export_tar() {
  local BORG_ARCHIVE=$1
  local TARGET_FILE=$2
  print_info "Exporting tar archive from backup ${BORG_ARCHIVE} to file ${TARGET_FILE}..."
  if borg export-tar --tar-filter=auto "${REPO_DIR}"::"${BORG_ARCHIVE}" "${TARGET_FILE}"; then
    print_info "Tar file has been successfully exported."
  else
    print_err "Error during tar file export. Aborting."
    exit 1
  fi  
}

if [ "$#" -lt 1 ]; then
    print_info "Please specify the action you want to perform."
    print_info "Valid actions: create, list, list <BACKUPNAME>, delete <BACKUPNAME>, info, info <BACKUPNAME>, check, prune, sync, mount <MOUNTPOINT>, export-tar <BACKUPNAME> <FILENAME>."
    exit 0
fi

check_dependencies
load_config
check_config

if [ ! -f "${PW_FILE}" ]; then
  generate_password
fi

if [ ! -d "${REPO_DIR}" ]; then
  init_repo  
fi

case "$1" in
create)
  borg_backup "${BACKUP_NAME}"
  borg_prune  
  sync_repo
  ;;
list)
  if [ "$#" -gt 1 ]; then
    borg_list "$2" 
  else
    borg_list
  fi
  ;;
delete)
  if [ ! "$#" -eq 2 ]; then
    print_err "Please provide a backup to delete."
    exit 1
  fi
  borg_delete "$2"
  ;;
prune)
  borg_prune
  ;;
sync)
  sync_repo
  ;;
info)
  if [ "$#" -gt 1 ]; then
    borg_info "$2" 
  else
    borg_info
  fi
  ;;
check)
  borg_check
  ;;
mount)
  if [ ! "$#" -eq 2 ]; then
    print_err "Please provide a mountpoint. Example: locutus.sh mount /mount/point"
    exit 1
  fi
  borg_mount "$2"
  ;;
export-tar)
  if [ ! "$#" -eq 3 ]; then
    print_err "Please provide a backup archive name and a target file. Example: locutus.sh 20190223-121420 /target/file/name.tar.xz"
    exit 1
  fi
  borg_export_tar "$2" "$3"
  ;;
*)
  print_err "Unknown action: $1"
  ;;
esac
