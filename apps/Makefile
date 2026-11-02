# SiteDrop role apps — run/build with dart-defines
# Usage (from sitedrop/apps/):  make run-buyer-dev
#
# Override secrets on the CLI:
#   make run-buyer-dev MAPS_KEY=AIza... VAPID=BE...
#   make apk-driver-prod MAPS_KEY=AIza...

SHELL := /bin/bash

# Defaults (override via environment or make VAR=...)
# Chrome/desktop default. Android emulator: make run-buyer-dev API_DEV=http://10.0.2.2:8000
API_DEV  ?= http://localhost:8000
API_PROD ?= https://api.sitedrop.com
MAPS_KEY ?=
VAPID    ?=
ENABLE_FIREBASE ?= true

BUYER_DIR  := buyer_app
SELLER_DIR := seller_app
DRIVER_DIR := driver_app

COMMON_DEV = --dart-define=API_BASE_URL=$(API_DEV) \
	--dart-define=ENABLE_FIREBASE=$(ENABLE_FIREBASE) \
	--dart-define=GOOGLE_MAPS_API_KEY=$(MAPS_KEY)

COMMON_PROD = --dart-define=API_BASE_URL=$(API_PROD) \
	--dart-define=ENABLE_FIREBASE=$(ENABLE_FIREBASE) \
	--dart-define=GOOGLE_MAPS_API_KEY=$(MAPS_KEY)

.PHONY: help get run-buyer-dev run-seller-dev run-driver-dev \
	apk-buyer-prod apk-seller-prod apk-driver-prod analyze

help:
	@echo "Targets:"
	@echo "  make run-buyer-dev|run-seller-dev|run-driver-dev"
	@echo "  make apk-buyer-prod|apk-seller-prod|apk-driver-prod"
	@echo "  make get | analyze"
	@echo "Vars: API_DEV API_PROD MAPS_KEY VAPID ENABLE_FIREBASE"

get:
	cd $(BUYER_DIR) && flutter pub get
	cd $(SELLER_DIR) && flutter pub get
	cd $(DRIVER_DIR) && flutter pub get

analyze:
	cd $(BUYER_DIR) && flutter analyze lib
	cd $(SELLER_DIR) && flutter analyze lib
	cd $(DRIVER_DIR) && flutter analyze lib

# ── Dev run ──────────────────────────────────────────────────────────
run-buyer-dev:
	cd $(BUYER_DIR) && flutter run \
		$(COMMON_DEV) \
		--dart-define=APP_ROLE=buyer \
		--dart-define=FIREBASE_VAPID_KEY=$(VAPID) \
		--dart-define=BACKGROUND_LOCATION=false

run-seller-dev:
	cd $(SELLER_DIR) && flutter run \
		$(COMMON_DEV) \
		--dart-define=APP_ROLE=seller \
		--dart-define=BACKGROUND_LOCATION=false

run-driver-dev:
	cd $(DRIVER_DIR) && flutter run \
		$(COMMON_DEV) \
		--dart-define=APP_ROLE=driver \
		--dart-define=BACKGROUND_LOCATION=true

# ── Release APK ──────────────────────────────────────────────────────
apk-buyer-prod:
	cd $(BUYER_DIR) && flutter build apk --release \
		$(COMMON_PROD) \
		--dart-define=APP_ROLE=buyer \
		--dart-define=FIREBASE_VAPID_KEY=$(VAPID) \
		--dart-define=BACKGROUND_LOCATION=false

apk-seller-prod:
	cd $(SELLER_DIR) && flutter build apk --release \
		$(COMMON_PROD) \
		--dart-define=APP_ROLE=seller \
		--dart-define=BACKGROUND_LOCATION=false

apk-driver-prod:
	cd $(DRIVER_DIR) && flutter build apk --release \
		$(COMMON_PROD) \
		--dart-define=APP_ROLE=driver \
		--dart-define=BACKGROUND_LOCATION=true
