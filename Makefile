NAME = plugn
HARDWARE = $(shell uname -m)
SYSTEM_NAME  = $(shell uname -s | tr '[:upper:]' '[:lower:]')
VERSION ?= 0.3.1
IMAGE_NAME ?= $(NAME)
BUILD_TAG ?= dev

build:
	go-bindata bashenv
	$(MAKE) build/darwin/$(NAME)
	$(MAKE) build/linux/$(NAME)
ifeq ($(CIRCLECI),true)
	docker build -t $(IMAGE_NAME):$(BUILD_TAG) .
else
	docker build -f Dockerfile.dev -t $(IMAGE_NAME):$(BUILD_TAG) .
endif


build/darwin/$(NAME):
	mkdir -p build/darwin
	CGO_ENABLED=0 GOOS=darwin go build -a -asmflags=-trimpath=/src -gcflags=-trimpath=/src \
										-ldflags "-X main.Version=$(VERSION)" \
										-o build/darwin/$(NAME)

build/linux/$(NAME):
	mkdir -p build/linux
	CGO_ENABLED=0 GOOS=linux go build -a -asmflags=-trimpath=/src -gcflags=-trimpath=/src \
										-ldflags "-X main.Version=$(VERSION)" \
										-o build/linux/$(NAME)

deps:
	go get -u github.com/jteeuwen/go-bindata/...
	go get -u github.com/progrium/basht/...

bin/gh-release:
	mkdir -p bin
	curl -o bin/gh-release.tgz -sL https://github.com/progrium/gh-release/releases/download/v2.2.1/gh-release_2.2.1_$(SYSTEM_NAME)_$(HARDWARE).tgz
	tar xf bin/gh-release.tgz -C bin
	chmod +x bin/gh-release

release: build bin/gh-release
	rm -rf release && mkdir release
	tar -zcf release/$(NAME)_$(VERSION)_linux_$(HARDWARE).tgz -C build/linux $(NAME)
	tar -zcf release/$(NAME)_$(VERSION)_darwin_$(HARDWARE).tgz -C build/darwin $(NAME)
	bin/gh-release create dokku/$(NAME) $(VERSION) $(shell git rev-parse --abbrev-ref HEAD)

build-in-docker:
	docker build --rm -f Dockerfile.build -t $(NAME)-build .
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro \
		-v /var/lib/docker:/var/lib/docker \
		-v ${PWD}:/src/github.com/dokku/plugn -w /src/github.com/dokku/plugn \
		-e IMAGE_NAME=$(IMAGE_NAME) -e BUILD_TAG=$(BUILD_TAG) -e VERSION=master \
		$(NAME)-build make -e deps build
	docker rmi $(NAME)-build || true

test:
	basht tests/*/tests.sh

circleci:
	docker version
	rm -f ~/.gitconfig
	mv Dockerfile.dev Dockerfile

clean:
	rm -rf build/*
	docker rm $(shell docker ps -aq) || true
	docker rmi plugn:dev || true

.PHONY: build release deps build-in-docker clean test circleci
