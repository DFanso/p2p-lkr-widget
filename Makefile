.PHONY: project build test sign-check icon clean

project:
	xcodegen generate

build: project
	xcodebuild -project P2PMonitor.xcodeproj -scheme P2PMonitor \
	  -configuration Debug CODE_SIGNING_ALLOWED=NO build

test:
	cd P2PKit && swift test

sign-check: project
	xcodebuild -project P2PMonitor.xcodeproj -scheme P2PMonitor \
	  -configuration Debug CODE_SIGN_STYLE=Manual \
	  CODE_SIGN_IDENTITY="Developer ID Application" \
	  OTHER_CODE_SIGN_FLAGS="--timestamp=none" build
	@APP=$$(find ~/Library/Developer/Xcode/DerivedData -name P2PMonitor.app -path '*Debug*' | head -1); \
	 echo "app:    $$APP"; \
	 ls "$$APP/Contents/PlugIns/" ; \
	 codesign -d --entitlements - --xml "$$APP" 2>/dev/null | plutil -convert xml1 -o - - | grep -A2 application-groups; \
	 codesign -d --entitlements - --xml "$$APP/Contents/PlugIns/P2PWidget.appex" 2>/dev/null | plutil -convert xml1 -o - - | grep -A2 application-groups

icon:
	swift tools/make-icon.swift

clean:
	rm -rf P2PMonitor.xcodeproj P2PKit/.build
