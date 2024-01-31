{
  description = "Example flake for running Rust code for ESP32C3 on a qemu emulator";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    qemu-espressif = {
      url = "github:SFrijters/nix-qemu-espressif";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { nixpkgs, flake-utils, qemu-espressif, rust-overlay, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        inherit (nixpkgs) lib;

        nixpkgs-patched = (import nixpkgs { inherit system; }).applyPatches {
          name = "nixpkgs-cargo-linker-workaround";
          src = nixpkgs;
          # Work around https://github.com/NixOS/nixpkgs/issues/281527 by forcing LLD as the linker:
          #   >   = note: x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '-flavor'
          #   >           x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '--as-needed'; did you mean '-mno-needed'?
          #   >           x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '--gc-sections'; did you mean '--data-sections'?
          #   >
          patches = [ ./nixpkgs-cargo-linker-workaround.patch ];
        };

        pkgs = import nixpkgs-patched {
          inherit system;
          overlays = [
            (import rust-overlay)
          ];
        };

        pkgsCross = import nixpkgs-patched {
          inherit system;
          crossSystem = {
            # We do not set system to something riscv related, which is kinda weird
            inherit system;
            rustc.config = "riscv32imc-unknown-none-elf";
          };
        };

        toolchain = (
          pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml
        );

        rustPlatform = pkgsCross.makeRustPlatform {
          rustc = toolchain;
          cargo = toolchain;
        };

        qemu-esp32c3 = qemu-espressif.packages.${system}.qemu-esp32c3;

        elf-binary = pkgs.callPackage ./blinky {
          inherit rustPlatform;
        };

        # elf-binary.name contains the system etc, e.g. "blinky-x86_64-unknown-linux-gnu"
        # Also: this is not "riscv" because we don't set system that way in pkgsCross
        name = builtins.head (lib.strings.splitString "-" elf-binary.name);

        emulate-script = pkgs.writeShellApplication {
          name = "emulate-${name}";
          runtimeInputs = [
            pkgs.cargo-espflash
            pkgs.netcat
            pkgs.gnugrep
            qemu-esp32c3
          ];
          text = ''
            # Some sanity checks
            file -b "${elf-binary}/bin/${name}" | grep "ELF 32-bit LSB executable.*UCB RISC-V.*soft-float ABI.*statically linked"
            # Create an image for qemu
            espflash save-image --chip esp32c3 --merge --format esp-bootloader ${elf-binary}/bin/${name} ${name}.bin
            # Start qemu in the background, open a tcp port to interact with it
            qemu-system-riscv32 -nographic -monitor tcp:127.0.0.1:55555,server,nowait -icount 3 -machine esp32c3 -drive file=${name}.bin,if=mtd,format=raw -serial file:qemu-blinky.log &
            # Wait a bit
            sleep 3s
            # Kill qemu nicely by sending 'q' (quit) over tcp
            echo q | nc -N 127.0.0.1 55555
            cat qemu-blinky.log
            # Sanity check
            grep "ESP-ROM:esp32c3-api1-20210207" qemu-blinky.log
            # Did we get the expected output?
            grep "Hello world" qemu-blinky.log
          '';
        };

        flash-script = pkgs.writeShellApplication {
          name = "flash-${name}";
          runtimeInputs = [
            pkgs.cargo-espflash
          ];
          text = ''
            espflash --monitor ${elf-binary}/bin/${name}
          '';
        };

      in
        {
          packages = {
            inherit elf-binary flash-script emulate-script;
            default = elf-binary;
          };

          checks.default = pkgs.stdenvNoCC.mkDerivation {
            name = "qemu-check-${name}";
            src = ./.;
            dontBuild = true;
            doCheck = true;
            checkPhase = ''
              ${lib.getExe emulate-script}
            '';
            installPhase = ''
              mkdir "$out"
              cp qemu-blinky.log "$out"
            '';
          };

          devShells.default = pkgs.mkShell {
            name = "${name}-dev";
            shellHook = ''
              echo "==> Using cargo version $(cargo --version)"
              echo "    Using rustc version $(rustc --version)"
              echo "    Using espflash version $(espflash --version)"
            '';
            buildInputs = [
              pkgs.cargo-espflash
              pkgs.cargo-generate
              qemu-esp32c3
              toolchain
            ];
          };

          apps = {
            default = {
              type = "app";
              program = "${lib.getExe emulate-script}";
            };

            emulate = {
              type = "app";
              program = "${lib.getExe emulate-script}";
            };

            flash = {
              type = "app";
              program = "${lib.getExe flash-script}";
            };
          };
        }
    );
}
