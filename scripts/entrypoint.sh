#! /usr/bin/env bash

set -eE -u -o pipefail
shopt -s inherit_errexit

function preflight_checks() {
  if [[ ! -v DEV_CONTAINER_BASE_DIR ]]; then
    echo "ERROR The environment variable 'DEV_CONTAINER_BASE_DIR' is not set"
    exit 1
  fi

  sudo rm -f "${DEV_CONTAINER_BASE_DIR}/.status/"*
}

function create_checkpoint() {
  local CHECKPOINT_NAME=${1:?Checkpoint name required}
  # CHECKPOINT_NAME=${CHECKPOINT_NAME// /_}

  sudo mkdir -p "${DEV_CONTAINER_BASE_DIR}/.status/"
  sudo touch "${DEV_CONTAINER_BASE_DIR}/.status/${CHECKPOINT_NAME}"
}

function run_init_scripts() {
  if [[ ! -d ${DEV_CONTAINER_BASE_DIR}/init_scripts ]]; then
    create_checkpoint '10-no_init_scripts_required'
    return 0
  fi

  for FILE in "${DEV_CONTAINER_BASE_DIR}/init_scripts/"*; do
    sudo /usr/bin/env bash "${FILE}"
  done

  create_checkpoint '11-init_scripts'
}

function main() {
  preflight_checks
  run_init_scripts

  create_checkpoint '99-main'
}

main
