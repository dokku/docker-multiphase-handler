.PHONY: publish clean

DOCKER_LINUX_IMAGE="fpco/stack-build:lts-14.13"
API_HOST=https://api.github.com
UPLOAD_HOST=https://uploads.github.com
DASH_VERSION=$(shell echo $(VERSION) | sed -e s/\\./-/g)

ifdef GITHUB_TOKEN
	AUTH=-H 'Authorization: token $(GITHUB_TOKEN)'
endif


# Utility target for checking required parameters
guard-%:
	@if [ "$($*)" = '' ]; then \
		echo "Missing required $* variable."; \
		exit 1; \
	fi;

dist-linux/docker-multiphase-handler:
	mkdir -p dist-linux
	stack --docker --docker-auto-pull --docker-image $(DOCKER_LINUX_IMAGE) install --local-bin-path dist-linux
	upx --best dist-linux/docker-multiphase-handler

dist-macos/docker-multiphase-handler:
	mkdir -p dist-macos
	stack install --local-bin-path dist-macos
	upx --best dist-macos/docker-multiphase-handler

release.json: dist-linux/docker-multiphase-handler dist-macos/docker-multiphase-handler
	@echo "Creating draft release for $(VERSION)"
	@curl $(AUTH) -XPOST $(API_HOST)/repos/dokku/docker-multiphase-handler/releases -d '{ \
		"tag_name": "$(VERSION)", \
		"name": "Docker build cacher $(VERSION)", \
		"draft": false, \
		"prerelease": false \
	}' > release.json
	@echo "Uploading binaries to github"

publish: guard-VERSION guard-GITHUB_TOKEN release.json
	$(eval RELEASE_ID := $(shell cat release.json | jq .id))
	@sleep 1
	@echo "Uploading the Linux docker-multiphase-handler"
	@curl $(AUTH) -XPOST \
		$(UPLOAD_HOST)/repos/dokku/docker-multiphase-handler/releases/$(RELEASE_ID)/assets?name=docker-multiphase-handler-linux \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary '@dist-linux/docker-multiphase-handler' > /dev/null
	@echo "Uploading the MacOS binary"
	@curl $(AUTH) -XPOST \
		$(UPLOAD_HOST)/repos/dokku/docker-multiphase-handler/releases/$(RELEASE_ID)/assets?name=docker-multiphase-handler-macos \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary '@dist-macos/docker-multiphase-handler' > /dev/null
	@echo Release done, you can go to:
	@cat release.json | jq .html_url


clean:
	rm -rf dist-*
	rm -f release.json
