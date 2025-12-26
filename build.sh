#!/bin/bash
set -e

# Build script for cli-universal image

PLATFORM="${PLATFORM:-linux/amd64}"
TAG="${TAG:-python3.12}"
VERSION="${VERSION:-latest}"
IMAGE_NAME="cli-universal"

echo "Building ${IMAGE_NAME}:${TAG} for ${PLATFORM}..."

if command -v podman &> /dev/null; then
    TOOL="podman"
elif command -v docker &> /dev/null; then
    TOOL="docker"
else
    echo "Error: Neither podman nor docker found!"
    exit 1
fi

echo "Using ${TOOL}..."
${TOOL} build --platform "${PLATFORM}" \
    -f Dockerfile \
    -t "${IMAGE_NAME}:${TAG}" \
    -t "${IMAGE_NAME}:${VERSION}" \
    -t "${IMAGE_NAME}:latest" .

echo ""
echo "Build complete!"
echo "Images tagged:"
echo "  - ${IMAGE_NAME}:${TAG}"
echo "  - ${IMAGE_NAME}:${VERSION}"
echo "  - ${IMAGE_NAME}:latest"
echo "Size: $(${TOOL} images ${IMAGE_NAME}:${TAG} --format '{{.Size}}')"
echo ""
echo "Test with:"
echo "  ${TOOL} run --rm ${IMAGE_NAME}:${TAG} -c 'python3 --version'"
echo ""
echo "For derived images, see examples/Dockerfile.child"
