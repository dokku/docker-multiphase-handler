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

build/linux/docker-multiphase-handler:
	mkdir -p build/linux
	stack --docker --docker-auto-pull --docker-image $(DOCKER_LINUX_IMAGE) install --local-bin-path build/linux
	upx --best build/linux/docker-multiphase-handler

build/macos/docker-multiphase-handler:
	mkdir -p build/macos
	stack install --local-bin-path build/macos
	upx --best build/macos/docker-multiphase-handler

build/debian/docker-multiphase-handler.deb: guard-VERSION
	mkdir -p build/debian
	fpm -t deb -s dir -n docker-multiphase-handler \
	    --version $(VERSION) \
	    --architecture amd64 \
	    --package build/debian/docker-multiphase-handler.deb \
	    --url "https://github.com/dokku/docker-multiphase-handler" \
	    --description 'Enables proper handling of multiphase dockerfiles' \
	    --license 'MIT License' \
	    build/linux/docker-multiphase-handler=/usr/bin/docker-multiphase-handler

build/centos/docker-multiphase-handler.rpm: guard-VERSION
	mkdir -p build/centos
	fpm -t rpm -s dir -n docker-multiphase-handler \
	    --version $(VERSION) \
	    --architecture x86_64 \
	    --package build/centos/docker-multiphase-handler.rpm \
	    --url "https://github.com/dokku/docker-multiphase-handler" \
	    --description 'Enables proper handling of multiphase dockerfiles' \
	    --license 'MIT License' \
	    build/linux/docker-multiphase-handler=/usr/bin/docker-multiphase-handler

release.json: build/linux/docker-multiphase-handler build/macos/docker-multiphase-handler build/debian/docker-multiphase-handler.deb build/centos/docker-multiphase-handler.rpm
	@echo "Creating draft release for $(VERSION)"
	@curl $(AUTH) -XPOST $(API_HOST)/repos/dokku/docker-multiphase-handler/releases -d '{ \
		"tag_name": "$(VERSION)", \
		"name": "Docker Multiphase Handler $(VERSION)", \
		"draft": false, \
		"prerelease": false \
	}' > release.json
	@echo "Uploading binaries to github"

publish: guard-VERSION guard-GITHUB_TOKEN release.json
	$(eval RELEASE_ID := $(shell cat release.json | jq .id))
	@sleep 1
	@echo "Uploading Linux binary"
	@curl $(AUTH) -XPOST \
		$(UPLOAD_HOST)/repos/dokku/docker-multiphase-handler/releases/$(RELEASE_ID)/assets?name=docker-multiphase-handler-linux \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary '@build/linux/docker-multiphase-handler' > /dev/null
	@echo "Uploading MacOS binary"
	@curl $(AUTH) -XPOST \
		$(UPLOAD_HOST)/repos/dokku/docker-multiphase-handler/releases/$(RELEASE_ID)/assets?name=docker-multiphase-handler-macos \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary '@build/macos/docker-multiphase-handler' > /dev/null
	@echo "Uploading Debian package"
	@curl $(AUTH) -XPOST \
		$(UPLOAD_HOST)/repos/dokku/docker-multiphase-handler/releases/$(RELEASE_ID)/assets?name=docker-multiphase-handler.deb \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary '@build/debian/docker-multiphase-handler.deb' > /dev/null
	@echo "Uploading RPM package"
	@curl $(AUTH) -XPOST \
		$(UPLOAD_HOST)/repos/dokku/docker-multiphase-handler/releases/$(RELEASE_ID)/assets?name=docker-multiphase-handler.rpm \
		-H "Accept: application/vnd.github.manifold-preview" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary '@build/centos/docker-multiphase-handler.rpm' > /dev/null
	@echo Release done, you can go to:
	@cat release.json | jq .html_url

clean:
	rm -rf build
	rm -f release.json
