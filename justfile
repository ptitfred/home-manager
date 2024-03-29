# This message
help:
  just -l

# Test various home-manager configurations
test:
  nix run home-manager/release-23.11 -- build --flake .#test-virtual-machine
  nix run home-manager/release-23.11 -- build --flake .#test-laptop

# Lint nix files
lint:
  nix run .#lint
