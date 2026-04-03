{
  description = "Nix-packaged MCP debug servers for Android, Browser, and iOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Real packages
        mcp-android = import ./android { inherit pkgs; };

        # Placeholder packages — will be replaced in later phases

        mcp-browser = pkgs.writeShellScriptBin "mcp-browser" ''
          echo "mcp-browser placeholder"
        '';

        mcp-ios = pkgs.writeShellScriptBin "mcp-ios" ''
          echo "mcp-ios placeholder"
        '';

        test-app-android = pkgs.writeShellScriptBin "test-app-android" ''
          echo "test-app-android placeholder"
        '';

        test-app-web = pkgs.runCommand "test-app-web" { } ''
          mkdir -p $out
          echo "<html><body>placeholder</body></html>" > $out/index.html
        '';

        # Default package: symlinkJoin of all platform-appropriate packages
        defaultPackages =
          if pkgs.stdenv.isDarwin
          then [ mcp-browser mcp-ios ]
          else [ mcp-android mcp-browser ];

      in {
        packages = {
          inherit mcp-android mcp-browser mcp-ios test-app-android test-app-web;
          default = pkgs.symlinkJoin {
            name = "nix-mcp-debugkit";
            paths = defaultPackages;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            statix
            deadnix
            shellcheck
            gitleaks
            trivy
            semgrep
            jq
            python3
            nodejs
            android-tools
          ];
        };

        checks = {
          smoke = pkgs.runCommand "smoke-tests" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.jq
              pkgs.shellcheck
              mcp-android
              mcp-browser
              mcp-ios
              test-app-android
            ];
          } ''
            export HOME="$TMPDIR"
            export DEFAULT_PKG_PATH="${pkgs.symlinkJoin {
              name = "nix-mcp-debugkit";
              paths = defaultPackages;
            }}"
            export TEST_APP_PATHS="${test-app-android}/bin/test-app-android:${test-app-web}"
            cp -r ${./tests}/* "$TMPDIR/"
            cd "$TMPDIR"
            bash smoke.sh
            cp -r test-logs "$out"
          '';
        };
      }
    ) // {
      overlays.default = _final: prev:
        let sys = prev.stdenv.hostPlatform.system; in {
          inherit (self.packages.${sys}) mcp-android mcp-browser mcp-ios;
        };
    };
}
