# typed: false
# frozen_string_literal: true

# Homebrew formula for obs-mcp
# Install with: brew tap cdavis-code/obs-websocket && brew install obs-mcp
class ObsMcp < Formula
  desc "MCP server for controlling OBS Studio via the obs-websocket v5.x protocol"
  homepage "https://github.com/cdavis-code/obs_websocket_workspace"
  version "5.7.1+4"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/cdavis-code/obs_websocket_workspace/releases/download/v#{version}/obs-mcp-darwin-arm64"
      sha256 "ARM64_MACOS_SHA256"
    else
      url "https://github.com/cdavis-code/obs_websocket_workspace/releases/download/v#{version}/obs-mcp-darwin-amd64"
      sha256 "AMD64_MACOS_SHA256"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/cdavis-code/obs_websocket_workspace/releases/download/v#{version}/obs-mcp-linux-arm64"
      sha256 "ARM64_LINUX_SHA256"
    else
      url "https://github.com/cdavis-code/obs_websocket_workspace/releases/download/v#{version}/obs-mcp-linux-amd64"
      sha256 "AMD64_LINUX_SHA256"
    end
  end

  # Development / HEAD install: brew install --head obs-mcp
  head "https://github.com/cdavis-code/obs_websocket_workspace.git", branch: "main"

  def install
    bin.install Dir["*"].first => "obs-mcp"
  end

  test do
    assert_match "usage", shell_output("#{bin}/obs-mcp --help 2>&1 || true")
  end
end
