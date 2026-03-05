#!/bin/bash
set -euo pipefail
#
# Build Script (OpenClaw Sandbox Variant)
# Description: Builds OpenClaw-compatible sandbox images for multiple architectures.
# Usage: ./build_openclaw_sandbox.sh
# Environment:
#   PLATFORMS        (default: linux/amd64,linux/arm64)
#   BASE_IMAGE       (default: cli-universal:python3.12)
#   BASE_IMAGE_AMD64 (optional override for amd64 base image)
#   BASE_IMAGE_ARM64 (optional override for arm64 base image)
#   TAG              (default: openclaw-sandbox)
#   IMAGE_NAME       (default: cli-universal)
#   CREATE_MANIFEST  (default: 1)
#   RUN_SMOKE_TEST   (default: 1)
#

BASE_IMAGE="${BASE_IMAGE:-cli-universal:python3.12}"
BASE_IMAGE_AMD64="${BASE_IMAGE_AMD64:-}"
BASE_IMAGE_ARM64="${BASE_IMAGE_ARM64:-}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
TAG="${TAG:-openclaw-sandbox}"
IMAGE_NAME="${IMAGE_NAME:-cli-universal}"
CREATE_MANIFEST="${CREATE_MANIFEST:-1}"
RUN_SMOKE_TEST="${RUN_SMOKE_TEST:-1}"
MANIFEST_CREATED=0

echo "Building ${IMAGE_NAME}:${TAG} for ${PLATFORMS}..."
echo "Base image (default): ${BASE_IMAGE}"

if command -v docker >/dev/null 2>&1; then
    TOOL="docker"
elif command -v podman >/dev/null 2>&1; then
    TOOL="podman"
else
    echo "Error: Neither podman nor docker found!"
    exit 1
fi

image_exists() {
    local image_ref="${1:?image ref required}"
    if [ "${TOOL}" = "docker" ]; then
        docker image inspect "${image_ref}" >/dev/null 2>&1
    else
        podman image exists "${image_ref}" >/dev/null 2>&1
    fi
}

resolve_base_image() {
    local platform="${1:?platform required}"
    local arch="${platform##*/}"
    local override=""
    local arch_suffixed=""

    case "${arch}" in
        amd64)
            override="${BASE_IMAGE_AMD64}"
            ;;
        arm64)
            override="${BASE_IMAGE_ARM64}"
            ;;
    esac

    if [ -n "${override}" ]; then
        printf '%s' "${override}"
        return 0
    fi

    arch_suffixed="${BASE_IMAGE}-${arch}"
    if image_exists "${arch_suffixed}"; then
        printf '%s' "${arch_suffixed}"
        return 0
    fi

    printf '%s' "${BASE_IMAGE}"
}

build_for_platform() {
    local platform="${1:?platform required}"
    local arch="${platform##*/}"
    local target_tag="${IMAGE_NAME}:${TAG}-${arch}"
    local base_for_platform
    base_for_platform="$(resolve_base_image "${platform}")"

    echo ""
    echo "[build] platform=${platform}"
    echo "[build] target=${target_tag}"
    echo "[build] base=${base_for_platform}"

    if [ "${TOOL}" = "docker" ]; then
        docker buildx build \
            --platform "${platform}" \
            --load \
            -f Dockerfile.openclaw-sandbox \
            --build-arg "BASE_IMAGE=${base_for_platform}" \
            -t "${target_tag}" \
            .
    else
        podman build \
            --platform "${platform}" \
            -f Dockerfile.openclaw-sandbox \
            --build-arg "BASE_IMAGE=${base_for_platform}" \
            -t "${target_tag}" \
            .
    fi
}

smoke_test_for_platform() {
    local platform="${1:?platform required}"
    local arch="${platform##*/}"
    local image_ref="${IMAGE_NAME}:${TAG}-${arch}"
    local tmp_workspace

    tmp_workspace="$(mktemp -d)"
    trap 'rm -rf "${tmp_workspace}"' RETURN
    echo "smoke-ok" > "${tmp_workspace}/.smoke"

    echo "[smoke] ${platform} (${image_ref})"
    "${TOOL}" run --rm --platform "${platform}" "${image_ref}" bash -lc \
        'test "$(whoami)" = "sandbox" && test "$(pwd)" = "/workspace" && codex --version && copilot --version && gemini --version'

    "${TOOL}" run --rm --platform "${platform}" \
        -v "${tmp_workspace}:/workspace" \
        -w /workspace \
        "${image_ref}" bash -lc \
        'test -f /workspace/.smoke && test "$(cat /workspace/.smoke)" = "smoke-ok"'
}

echo "Using ${TOOL}..."
if [ "${TOOL}" = "docker" ]; then
    docker buildx inspect >/dev/null 2>&1 || {
        echo "Error: docker buildx is required for multi-architecture builds."
        exit 1
    }
fi

IFS=',' read -r -a PLATFORM_LIST <<< "${PLATFORMS}"
if [ "${#PLATFORM_LIST[@]}" -eq 0 ]; then
    echo "Error: PLATFORMS is empty"
    exit 1
fi

for platform in "${PLATFORM_LIST[@]}"; do
    build_for_platform "${platform}"
done

if [ "${CREATE_MANIFEST}" = "1" ] && [ "${#PLATFORM_LIST[@]}" -gt 1 ]; then
    manifest_ref="${IMAGE_NAME}:${TAG}"
    echo ""
    echo "[manifest] creating ${manifest_ref}"
    if [ "${TOOL}" = "docker" ]; then
        if docker manifest rm "${manifest_ref}" >/dev/null 2>&1 || true; \
           manifest_inputs=(); \
           for platform in "${PLATFORM_LIST[@]}"; do \
             arch="${platform##*/}"; \
             manifest_inputs+=("${IMAGE_NAME}:${TAG}-${arch}"); \
           done; \
           docker manifest create "${manifest_ref}" "${manifest_inputs[@]}"; then
            for platform in "${PLATFORM_LIST[@]}"; do
                arch="${platform##*/}"
                docker manifest annotate "${manifest_ref}" "${IMAGE_NAME}:${TAG}-${arch}" --arch "${arch}"
            done
            MANIFEST_CREATED=1
        else
            echo "[manifest] warning: failed to create local manifest '${manifest_ref}', continuing with per-arch images."
        fi
    else
        if podman manifest rm "${manifest_ref}" >/dev/null 2>&1 || true; \
           podman manifest create "${manifest_ref}"; then
            for platform in "${PLATFORM_LIST[@]}"; do
                arch="${platform##*/}"
                podman manifest add "${manifest_ref}" "${IMAGE_NAME}:${TAG}-${arch}"
            done
            MANIFEST_CREATED=1
        else
            echo "[manifest] warning: failed to create local manifest '${manifest_ref}', continuing with per-arch images."
        fi
    fi
fi

if [ "${RUN_SMOKE_TEST}" = "1" ]; then
    echo ""
    echo "[smoke] running smoke tests"
    for platform in "${PLATFORM_LIST[@]}"; do
        smoke_test_for_platform "${platform}"
    done
fi

echo ""
echo "Build complete!"
echo "Images:"
for platform in "${PLATFORM_LIST[@]}"; do
    arch="${platform##*/}"
    echo "  - ${IMAGE_NAME}:${TAG}-${arch}"
done
if [ "${MANIFEST_CREATED}" = "1" ]; then
    echo "  - ${IMAGE_NAME}:${TAG} (manifest)"
fi
echo ""
echo "Done."
