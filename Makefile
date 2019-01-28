dev:
	$(eval export env_stub=dev)
	@true

test:
	$(eval export env_stub=test)
	@true

integration:
	$(eval export env_stub=integration)
	@true

live:
	$(eval export env_stub=live)
	@true

init:
	$(eval export ECR_REPO_NAME=fb-service-token-cache)
	$(eval export ECR_REPO_URL=926803513772.dkr.ecr.eu-west-1.amazonaws.com/formbuilder/fb-service-token-cache)

# install aws cli w/o sudo
install_build_dependencies: init
	docker --version
	pip install --user awscli
	$(eval export PATH=${PATH}:${HOME}/.local/bin/)


# Needs ECR_REPO_NAME & ECR_REPO_URL env vars
build: install_build_dependencies
	docker build -t ${ECR_REPO_NAME}:latest-${env_stub} -f docker/Dockerfile . && \
		docker tag ${ECR_REPO_NAME}:latest-${env_stub} ${ECR_REPO_URL}:latest-${env_stub}

login: init
	@eval $(shell aws ecr get-login --no-include-email --region eu-west-1)

push: login
	docker push ${ECR_REPO_URL}:latest-${env_stub}

build_and_push: build push

.PHONY := init push build login
