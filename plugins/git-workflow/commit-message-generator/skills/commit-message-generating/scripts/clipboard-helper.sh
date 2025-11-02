#!/usr/bin/env bash

# Clipboard Helper Functions
# Cross-platform clipboard operations for commit message generation

set -euo pipefail

#######################################
# Detect the operating system platform
# Outputs: "macos", "linux", "wsl", or "unknown"
# Returns: 0 always
#######################################
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

#######################################
# Detect available clipboard tool for the current platform
# Outputs: Tool name (pbcopy, xclip, xsel, wl-copy, clip.exe) or "none"
# Returns: 0 if tool found, 1 if none available
#######################################
detect_clipboard_tool() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        macos)
            if command -v pbcopy &> /dev/null; then
                echo "pbcopy"
                return 0
            fi
            ;;
        wsl)
            if command -v clip.exe &> /dev/null; then
                echo "clip.exe"
                return 0
            fi
            ;;
        linux)
            # Check for Wayland first
            if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
                if command -v wl-copy &> /dev/null; then
                    echo "wl-copy"
                    return 0
                fi
            fi

            # Fall back to X11 tools
            if command -v xclip &> /dev/null; then
                echo "xclip"
                return 0
            elif command -v xsel &> /dev/null; then
                echo "xsel"
                return 0
            fi
            ;;
        *)
            ;;
    esac

    echo "none"
    return 1
}

#######################################
# Copy text to system clipboard
# Arguments:
#   $1 - Text to copy to clipboard
# Returns: 0 if successful, 1 if clipboard tool unavailable or copy failed
#######################################
copy_to_clipboard() {
    if [ $# -eq 0 ]; then
        echo "Error: No text provided to copy" >&2
        return 1
    fi

    local text="$1"
    local tool

    if ! tool=$(detect_clipboard_tool); then
        local platform
        platform=$(detect_platform)

        echo "Error: No clipboard tool available for platform '$platform'" >&2
        echo "" >&2
        echo "Install one of the following:" >&2

        case "$platform" in
            macos)
                echo "  - pbcopy (should be pre-installed on macOS)" >&2
                ;;
            wsl)
                echo "  - clip.exe (should be available in WSL)" >&2
                ;;
            linux)
                if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
                    echo "  - wl-clipboard: sudo apt-get install wl-clipboard" >&2
                else
                    echo "  - xclip: sudo apt-get install xclip" >&2
                    echo "  - xsel: sudo apt-get install xsel" >&2
                fi
                ;;
            *)
                echo "  - Unsupported platform" >&2
                ;;
        esac

        return 1
    fi

    case "$tool" in
        pbcopy)
            if echo "$text" | pbcopy; then
                return 0
            fi
            ;;
        xclip)
            if echo "$text" | xclip -selection clipboard; then
                return 0
            fi
            ;;
        xsel)
            if echo "$text" | xsel --clipboard --input; then
                return 0
            fi
            ;;
        wl-copy)
            if echo "$text" | wl-copy; then
                return 0
            fi
            ;;
        clip.exe)
            if echo "$text" | clip.exe; then
                return 0
            fi
            ;;
        *)
            echo "Error: Unknown clipboard tool '$tool'" >&2
            return 1
            ;;
    esac

    echo "Error: Failed to copy to clipboard using '$tool'" >&2
    return 1
}

# Export functions for use in other scripts
export -f detect_platform
export -f detect_clipboard_tool
export -f copy_to_clipboard
