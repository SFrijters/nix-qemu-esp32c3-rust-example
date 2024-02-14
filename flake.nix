{
  description = "Running Rust code for ESP32C3 on a QEMU emulator";
  inputs = {
    qemu-espressif.url = "github:SFrijters/nix-qemu-espressif";
    flake-utils.follows = "qemu-espressif/flake-utils";
    nixpkgs.follows = "qemu-espressif/nixpkgs";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "qemu-espressif/nixpkgs";
        flake-utils.follows = "qemu-espressif/flake-utils";
      };
    };
  };

  outputs = { nixpkgs, flake-utils, qemu-espressif, rust-overlay, ... }:
    # Maybe other systems work as well, but they have not been tested
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        inherit (nixpkgs) lib;

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import rust-overlay)
          ];
        };

        pkgsCross = import nixpkgs {
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
          inherit rustPlatform pkgsCross;
        };

        inherit (elf-binary.meta) name;

        emulate-script = pkgs.writeShellApplication {
          name = "emulate-${name}";
          runtimeInputs = [
            pkgs.cargo-espflash
            pkgs.esptool
            pkgs.gnugrep
            pkgs.netcat
            qemu-esp32c3
          ];
          text = ''
            # Some sanity checks
            file -b "${elf-binary}/bin/${name}" | grep "ELF 32-bit LSB executable.*UCB RISC-V.*soft-float ABI.*statically linked"
            # Create an image for qemu
            espflash save-image --chip esp32c3 --merge --format esp-bootloader ${elf-binary}/bin/${name} ${name}.bin
            # Get stats
            esptool.py image_info --version 2 ${name}.bin
            # Start qemu in the background, open a tcp port to interact with it
            qemu-system-riscv32 -nographic -monitor tcp:127.0.0.1:55555,server,nowait -icount 3 -machine esp32c3 -drive file=${name}.bin,if=mtd,format=raw -serial file:qemu-${name}.log &
            # Wait a bit
            sleep 3s
            # Kill qemu nicely by sending 'q' (quit) over tcp
            echo q | nc -N 127.0.0.1 55555
            cat qemu-${name}.log
            # Sanity check
            grep "ESP-ROM:esp32c3-api1-20210207" qemu-${name}.log
            # Did we get the expected output?
            grep "Hello world" qemu-${name}.log
          '';
        };

        flash-script = pkgs.writeShellApplication {
          name = "flash-${name}";
          runtimeInputs = [
            pkgs.cargo-espflash
          ];
          text = ''
            espflash flash --monitor ${elf-binary}/bin/${name}
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
              cp qemu-${name}.log "$out"
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
              pkgs.cargo-generate
              pkgs.cargo-espflash
              pkgs.esptool
              pkgs.gnugrep
              pkgs.netcat
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
