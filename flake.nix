{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { pkgs, ... }: {
        devShells.default =
          let
            avrlibc = pkgs.pkgsCross.avr.libcCross;

            avr_incflags = [
              "-isystem ${avrlibc}/avr/include"
              "-B${avrlibc}/avr/lib/avr5"
              "-L${avrlibc}/avr/lib/avr5"
              "-B${avrlibc}/avr/lib/avr35"
              "-L${avrlibc}/avr/lib/avr35"
              "-B${avrlibc}/avr/lib/avr51"
              "-L${avrlibc}/avr/lib/avr51"
            ];
          in
          pkgs.mkShell {
            name = "qmk-firmware";

            packages = with pkgs; [
              nixd
              nixpkgs-fmt

              clang-tools
              dfu-programmer
              dfu-util

              pkgsCross.avr.buildPackages.binutils
              pkgsCross.avr.buildPackages.gcc8
              avrlibc
              avrdude

              gcc-arm-embedded

              teensy-loader-cli

              qmk
            ];

            AVR_CFLAGS = avr_incflags;
            AVR_ASFLAGS = avr_incflags;

            shellHook = ''
              unset NIX_CFLAGS_COMPILE_FOR_TARGET
            '';
          };

        apps =
          let
            flash = pkgs.writeShellApplication {
              name = "flash.sh";

              runtimeInputs = [ ];

              text = ''
                # if there are uncommited changes, exit after alerting user
                if ! git diff-index --quiet HEAD --; then
                  echo "There are uncommited changes. Aborting."
                  exit 1
                fi

                qmk compile
                qmk flash
              '';
            };

            update = pkgs.writeShellApplication {
              name = "update.sh";

              runtimeInputs = [ ];

              text = ''
                git checkout main
                git fetch upstream
                git pull upstream master
                git push origin main
              '';
            };
          in
          {
            flash.program = "${flash}/bin/flash.sh";

            update.program = "${update}/bin/update.sh";
          };
      };
    };
}
