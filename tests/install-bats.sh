#!/usr/bin/env bash
# install-bats.sh - Helper script to install bats-core testing framework

set -euo pipefail

echo "🧪 Installing bats-core testing framework..."

# Detect OS
OS="$(uname -s)"

case "$OS" in
  Darwin)
    echo "📦 Detected macOS"
    if command -v brew &> /dev/null; then
      echo "✅ Homebrew found, installing bats-core..."
      brew install bats-core
    else
      echo "❌ Homebrew not found. Please install Homebrew first:"
      echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
    ;;

  Linux)
    echo "📦 Detected Linux"

    # Check for package manager
    if command -v apt-get &> /dev/null; then
      echo "✅ Using apt-get..."
      sudo apt-get update
      sudo apt-get install -y bats
    elif command -v yum &> /dev/null; then
      echo "✅ Using yum..."
      sudo yum install -y bats
    elif command -v dnf &> /dev/null; then
      echo "✅ Using dnf..."
      sudo dnf install -y bats
    elif command -v pacman &> /dev/null; then
      echo "✅ Using pacman..."
      sudo pacman -S --noconfirm bats
    else
      echo "⚠️  No supported package manager found. Installing from source..."

      # Create temp directory
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"

      # Clone and install
      git clone https://github.com/bats-core/bats-core.git
      cd bats-core
      sudo ./install.sh /usr/local

      # Cleanup
      cd /
      rm -rf "$TEMP_DIR"
    fi
    ;;

  *)
    echo "❌ Unsupported OS: $OS"
    echo "Please install bats-core manually from: https://github.com/bats-core/bats-core"
    exit 1
    ;;
esac

# Verify installation
if command -v bats &> /dev/null; then
  echo ""
  echo "✅ bats-core installed successfully!"
  echo "📌 Version: $(bats --version)"
  echo ""
  echo "🚀 You can now run tests with:"
  echo "   cd $(dirname "$(dirname "$0")")"
  echo "   bats tests/setver.bats"
else
  echo "❌ Installation failed. Please install manually."
  exit 1
fi
