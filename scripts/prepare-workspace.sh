#!/usr/bin/env bash
set -euo pipefail

# Validates composite action inputs and prepares the temporary workspace
# and BuildKit options for Docker image builds.
#
# Usage:
#   prepare-workspace.sh <container_type> <version> <artifact_name> <artifact_id> <artifact_path> [enable_cache] [load_image]

CONTAINER_TYPE="${1:-}"
VERSION="${2:-}"
ARTIFACT_NAME="${3:-}"
ARTIFACT_ID="${4:-}"
ARTIFACT_PATH="${5:-}"
ENABLE_CACHE="${6:-false}"
LOAD_IMAGE="${7:-false}"

WORK_DIR=""
SOURCE_DIR=""
CONTEXT_DIR=""
CACHE_FROM=""
CACHE_TO=""
PROVENANCE=""

write_output() {
  echo "$1=$2" >> "${GITHUB_OUTPUT}"
}

validate_container_type() {
  case "${CONTAINER_TYPE}" in
    mariadb|mysql|opensearch|media) ;;
    *)
      echo "::error::Unsupported containerType '${CONTAINER_TYPE}'. Expected one of: mariadb, mysql, opensearch, media."
      exit 1
      ;;
  esac
}

should_skip_optional_build() {
  [[ "${CONTAINER_TYPE}" == "opensearch" && ( -z "${VERSION}" || "${VERSION}" == "none" ) ]]
}

validate_required_inputs() {
  if [[ "${CONTAINER_TYPE}" != "media" && ( -z "${VERSION}" || "${VERSION}" == "none" ) ]]; then
    echo "::error::Input 'version' is required when containerType is '${CONTAINER_TYPE}'."
    exit 1
  fi

  if [[ -z "${ARTIFACT_PATH}" && -z "${ARTIFACT_ID}" && -z "${ARTIFACT_NAME}" ]]; then
    echo "::error::One of 'artifact', 'artifactId', or 'artifactPath' must be specified."
    exit 1
  fi
}

prepare_directories() {
  WORK_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/magento-image-XXXXXX")"
  CONTEXT_DIR="${WORK_DIR}/context"
  mkdir -p "${CONTEXT_DIR}"

  if [[ -n "${ARTIFACT_PATH}" ]]; then
    if [[ ! -d "${ARTIFACT_PATH}" ]]; then
      echo "::error::Specified artifactPath '${ARTIFACT_PATH}' does not exist or is not a directory."
      rm -rf "${WORK_DIR}"
      exit 1
    fi
    SOURCE_DIR="$(cd "${ARTIFACT_PATH}" && pwd)"
  else
    SOURCE_DIR="${WORK_DIR}/download"
    mkdir -p "${SOURCE_DIR}"
  fi
}

configure_build_options() {
  if [[ "${ENABLE_CACHE}" != "false" ]]; then
    CACHE_FROM="type=gha"
    CACHE_TO="type=gha,mode=max"
  else
    CACHE_FROM=""
    CACHE_TO=""
  fi

  if [[ "${LOAD_IMAGE}" != "false" ]]; then
    PROVENANCE="false"
  else
    PROVENANCE="mode=max"
  fi
}

main() {
  validate_container_type

  if should_skip_optional_build; then
    echo "::notice::Skipping OpenSearch image build because 'version' is not specified."
    write_output "skip" "true"
    write_output "work_dir" ""
    exit 0
  fi

  validate_required_inputs
  prepare_directories
  configure_build_options

  write_output "skip" "false"
  write_output "work_dir" "${WORK_DIR}"
  write_output "source_dir" "${SOURCE_DIR}"
  write_output "context_dir" "${CONTEXT_DIR}"
  write_output "cache_from" "${CACHE_FROM}"
  write_output "cache_to" "${CACHE_TO}"
  write_output "provenance" "${PROVENANCE}"
}

main
