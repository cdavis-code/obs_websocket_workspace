# typed: false
# frozen_string_literal: true

# Homebrew formula for obs-mcp
# Install with: brew tap cdavis-code/obs-websocket && brew install obs-mcp
class ObsMcp < Formula
  desc "MCP server for controlling OBS Studio via the obs-websocket v5.x protocol"
  homepage "https://github.com/cdavis-code/obs_websocket_workspace"
  version "5.7.1+3"
  license "MIT"

  url "https://github.com/cdavis-code/obs_websocket_workspace/archive/refs/tags/v5.7.1+3.tar.gz"
  sha256 "3a98c876628169633b7a1857ad499cf4ebab360b8b6cbce6c4845d84d95738db"

  # Development / HEAD install: brew install --head obs-mcp
  head "https://github.com/cdavis-code/obs_websocket_workspace.git", branch: "main"

  depends_on "dart-sdk" => :build

  def install
    cd "packages/obs_mcp" do
      inreplace "pubspec.yaml", "resolution: workspace\n", ""
      system "dart", "pub", "get"
      system "dart", "compile", "exe",
             "bin/obs_mcp_server.dart",
             "-o", "obs-mcp"
      bin.install "obs-mcp"
    end
  end

  test do
    assert_match "usage", shell_output("#{bin}/obs-mcp --help 2>&1 || true")
  end
end
