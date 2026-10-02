#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root="$PWD"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_root/.build/swift-module-cache"
swift_options=(--disable-sandbox --cache-path "$project_root/.build/cache" --config-path "$project_root/.build/config" --security-path "$project_root/.build/security")
swift build "${swift_options[@]}" -c release --product PromptWheel
binary_dir="$(swift build "${swift_options[@]}" -c release --show-bin-path)"
app="$project_root/dist/Prompt Wheel.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/PromptWheel" "$app/Contents/MacOS/PromptWheel"
cp App/Info.plist "$app/Contents/Info.plist"
# Replace only this generated resource directory, never the editable user library.
if [ -d "$app/Contents/Resources/Prompts" ]; then
    rm -r "$app/Contents/Resources/Prompts"
fi
cp -R Prompts "$app/Contents/Resources/Prompts"
codesign --force --sign "${PROMPT_WHEEL_SIGNING_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
printf 'Built: %s\n' "$app"
