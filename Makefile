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

# Controller
define CONTROLLER_IMAGE_NAME
bookstore-controller
endef

define CONTROLLER_TAG
latest
endef

controller-build:
	mvn clean package -f ./src/controller/pom.xml --no-transfer-progress

controller-image-build: controller-build
	podman build -t $(ACR)/$(CONTROLLER_IMAGE_NAME):$(CONTROLLER_TAG) -f ./src/controller/Dockerfile ./src/controller

controller-image-push: controller-image-build
	podman push $(ACR)/$(CONTROLLER_IMAGE_NAME):$(CONTROLLER_TAG)

all: frontend-image-push controller-image-push

# Targeted builds
frontend: frontend-image-push
controller: controller-image-push

# needed to make sure the build always runs.
.PHONY: all frontend-image-build frontend-image-push frontend controller-build controller-image-build controller-image-push controller