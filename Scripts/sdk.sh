# Sourced by build-app.sh and check.sh. Picks a macOS SDK that can actually build SwiftUI and
# sets SDKROOT to it.
#
# Command Line Tools updates sometimes ship a new SDK whose SwiftUI needs a macro plugin the tools
# don't include (`@State` then fails with "plugin for module 'SwiftUIMacros' not found"). Instead
# of hard-coding an SDK, the first candidate that can work is used: SDKROOT if you set it, then
# Xcode's SDK, then the Command Line Tools SDKs, newest first. The check is a quick file lookup;
# only if no SDK passes it is each one tried with a (slow) test compile.

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR

pocket_sdk_builds_swiftui() {
    local probe
    probe="$(mktemp -d)/Probe.swift"
    printf 'import SwiftUI\nstruct Probe: View {\n    @State var count = 0\n    var body: some View { Text("\\(count)") }\n}\n' > "$probe"
    swiftc -sdk "$1" -target arm64-apple-macosx14.0 -typecheck "$probe" >/dev/null 2>&1
    local result=$?
    rm -rf "$(dirname "$probe")"
    return $result
}

# Whether the SDK's SwiftUI turns `@State` into a macro (every view uses it) and the tools don't
# have the SwiftUIMacros plugin that implements it. Older SDKs use other SwiftUI macros too, but
# those only matter to code that uses them.
pocket_sdk_missing_macros() {
    local sdk="$1"
    grep -rqs 'public macro State()' \
        "$sdk/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule" \
        "$sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule" || return 1
    local dir
    for dir in "$DEVELOPER_DIR/usr/lib/swift/host/plugins" \
               "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins" \
               "$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins" \
               "$sdk/usr/lib/swift/host/plugins"; do
        [[ -e "$dir/libSwiftUIMacros.dylib" ]] && return 1
    done
    return 0
}

pocket_choose_sdk() {
    # An SDK you picked yourself is used as is.
    if [[ -n "${SDKROOT:-}" ]]; then
        return 0
    fi
    local candidates=()
    local xcode_sdk="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    [[ -d "$xcode_sdk" ]] && candidates+=("$xcode_sdk")
    local clt="/Library/Developer/CommandLineTools/SDKs"
    if [[ -d "$clt" ]]; then
        [[ -d "$clt/MacOSX.sdk" ]] && candidates+=("$clt/MacOSX.sdk")
        # Versioned SDKs, newest first (MacOSX27.2.sdk before MacOSX26.5.sdk).
        while IFS= read -r sdk; do
            candidates+=("$clt/$sdk")
        done < <(ls "$clt" | grep -E '^MacOSX[0-9.]+\.sdk$' | sort -t X -k 2 -V -r)
    fi
    local sdk
    for sdk in "${candidates[@]}"; do
        if ! pocket_sdk_missing_macros "$sdk"; then
            export SDKROOT="$sdk"
            echo "› Using SDK: $(basename "$sdk")"
            return 0
        fi
    done
    # The quick check may not know where a future Xcode keeps the plugin: try compiling.
    for sdk in "${candidates[@]}"; do
        if pocket_sdk_builds_swiftui "$sdk"; then
            export SDKROOT="$sdk"
            echo "› Using SDK: $(basename "$sdk")"
            return 0
        fi
    done
    echo "No installed macOS SDK can build SwiftUI. Reinstall the developer tools:" >&2
    echo "    sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install" >&2
    return 1
}

pocket_choose_sdk || exit 1

# Swift Testing ships outside the default search paths when only the Command Line Tools are
# installed, so tests need to be told where it is.
POCKET_TEST_FLAGS=()
pocket_testing="$DEVELOPER_DIR/Library/Developer/Frameworks"
if [[ -d "$pocket_testing/Testing.framework" ]]; then
    POCKET_TEST_FLAGS+=(-Xswiftc -F -Xswiftc "$pocket_testing"
        -Xlinker -rpath -Xlinker "$pocket_testing"
        -Xlinker -rpath -Xlinker "$DEVELOPER_DIR/Library/Developer/usr/lib")
fi
