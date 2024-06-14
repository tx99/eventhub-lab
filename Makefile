# Global Variables
ACR?= andrewacr.azurecr.io

# Frontend
define FRONTEND_IMAGE_NAME
bookstore-frontend
endef

define FRONTEND_TAG
latest
endef

frontend-image-build:
	podman build -t $(ACR)/$(FRONTEND_IMAGE_NAME):$(FRONTEND_TAG) -f ./src/frontend/Docker/Dockerfile ./src/frontend

frontend-image-push: frontend-image-build
	podman push $(ACR)/$(FRONTEND_IMAGE_NAME):$(FRONTEND_TAG)


all: frontend-image-push 

# Targeted builds
frontend: frontend-image-push

# needed to make sure the buid always runs.
.PHONY: all frontend-image-build frontend-image-push frontend
