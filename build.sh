#!/bin/bash
set -e

# Build script for cli-universal image

PLATFORM="${PLATFORM:-linux/amd64}"
TAG="${TAG:-python3.12}"
IMAGE_NAME="cli-universal:${TAG}"

echo "Building ${IMAGE_NAME} for ${PLATFORM}..."

if command -v podman &> /dev/null; then
    echo "Using podman..."
    podman build --platform "${PLATFORM}" \
        -f Dockerfile \
        -t "${IMAGE_NAME}" .
    
    echo ""
    echo "Build complete!"
    echo "Image: ${IMAGE_NAME}"
    echo "Size: $(podman images ${IMAGE_NAME} --format '{{.Size}}')"
    echo ""
    echo "Test with:"
    echo "  podman run --rm ${IMAGE_NAME} -c 'python3 --version'"
    
elif command -v docker &> /dev/null; then
    echo "Using docker..."
    docker build --platform "${PLATFORM}" \
        -f Dockerfile \
        -t "${IMAGE_NAME}" .
    
    echo ""
    echo "Build complete!"
    echo "Image: ${IMAGE_NAME}"
    echo "Size: $(docker images ${IMAGE_NAME} --format '{{.Size}}')"
    echo ""
    echo "Test with:"
    echo "  docker run --rm ${IMAGE_NAME} -c 'python3 --version'"
else
    echo "Error: Neither podman nor docker found!"
    exit 1
fi
