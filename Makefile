.PHONY: deliver-ios

# IPA ビルド → App Store Connect アップロード（一括）
# 使い方:
#   make deliver-ios ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   make deliver-ios ASC_ISSUER_ID=... BUILD_NUMBER=10
#   make deliver-ios ASC_ISSUER_ID=... SKIP_BUILD=1
deliver-ios:
	@bash scripts/deliver_ios.sh \
		$(if $(ASC_ISSUER_ID),--issuer-id $(ASC_ISSUER_ID),) \
		$(if $(BUILD_NUMBER),--build-number $(BUILD_NUMBER),) \
		$(if $(SKIP_BUILD),--skip-build,)
