.PHONY: help verify ci manifest docs dockerfile build-args app-build app-verify image-build image-test image clean

# Path to the reviewed image manifest. Override this to point at a different
# manifest.
MANIFEST    ?= examples/image-manifest.json
IMAGE_TAG   ?= ubi9-hashicorp-vault:local
APP_PLATFORM ?= linux/amd64

help:
	@printf '%s\n' \
		'Contract checks (no Docker required):' \
		'  verify     Run the full local verification surface' \
		'  ci         Alias for verify' \
		'  manifest   Validate the starter image manifest contract' \
		'  docs       Validate documentation layout' \
		'  dockerfile Validate Dockerfile contract markers' \
		'  build-args Render docker buildx flags from the manifest' \
		'' \
		'End-to-end image lifecycle (Docker required):' \
		'  app-build  Download and verify Vault release artifacts' \
		'  app-verify Verify Vault artifact SHA256s match the manifest' \
		'  image-build Build the OCI image for $$APP_PLATFORM (default linux/amd64)' \
		'  image-test  Run runtime-hardening assertions against the built image' \
		'  image       app-build + app-verify + image-build + image-test' \
		'  clean       Remove dist/ build outputs'

verify:
	python tools/verify.py verify

ci:
	python tools/verify.py ci

manifest:
	python tools/check_image_manifest.py --template $(MANIFEST)

docs:
	python tools/verify.py docs-layout

dockerfile:
	python tools/verify.py dockerfile-contract

build-args:
	python tools/generate_build_args.py $(MANIFEST)

app-build:
	MANIFEST='$(MANIFEST)' bash tools/build_app.sh

app-verify:
	python tools/verify_app_shas.py $(MANIFEST)

image-build: app-verify
	bash tools/build_image.sh '$(MANIFEST)' '$(IMAGE_TAG)' '$(APP_PLATFORM)'

image-test:
	bash tests/runtime-hardening.sh '$(IMAGE_TAG)' /usr/local/bin/vault

image: app-build app-verify image-build image-test

clean:
	rm -rf dist
