{
  description = "Running Rust code for ESP32C3 on a QEMU emulator";
  inputs = {
    qemu-espressif.url = "github:SFrijters/nix-qemu-espressif";
    nixpkgs.follows = "qemu-espressif/nixpkgs";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "qemu-espressif/nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      qemu-espressif,
      rust-overlay,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      # Boilerplate to make the rest of the flake more readable
      # Do not inject system into these attributes
      flatAttrs = [
        "overlays"
        "nixosModules"
      ];
      # Inject a system attribute if the attribute is not one of the above
      injectSystem =
        system:
        lib.mapAttrs (name: value: if builtins.elem name flatAttrs then value else { ${system} = value; });
      # Combine the above for a list of 'systems'
      forSystems =
        systems: f:
        lib.attrsets.foldlAttrs (
          acc: system: value:
          lib.attrsets.recursiveUpdate acc (injectSystem system value)
        ) { } (lib.genAttrs systems f);

    in
    # Maybe other systems work as well, but they have not been tested
    forSystems
      [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (import rust-overlay)
              (import qemu-espressif)
            ];
          };

          pkgsCross = import nixpkgs {
            inherit system;
            crossSystem = {
              # https://github.com/NixOS/nixpkgs/issues/281527#issuecomment-2180971963
              inherit system;
              rust.rustcTarget = "riscv32imc-unknown-none-elf";
            };
          };

          toolchain = (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml);

          rustPlatform = pkgsCross.makeRustPlatform {
            rustc = toolchain;
            cargo = toolchain;
          };

          # Pin espflash to 3.3.0 for now; when using the new 4.0.0 the emulation goes into a boot loop
          # Complicated way to override this:
          # https://discourse.nixos.org/t/is-it-possible-to-override-cargosha256-in-buildrustpackage/4393/20
          espflash_3_3_0 = pkgs.espflash.override
            (
              let
                version = "3.3.0";
                rp = pkgs.rustPlatform;
              in
                {
                  rustPlatform = rp // {
                    buildRustPackage = args: rp.buildRustPackage (
                      args // rec {
                        inherit version;

                        src = pkgs.fetchFromGitHub {
                          owner = "esp-rs";
                          repo = "espflash";
                          tag = "v${version}";
                          hash = "sha256-8qFq+OyidW8Bwla6alk/9pXLe3zayHkz5LsqI3jwgY0=";
                        };

                        cargoHash = "sha256-WEPSXgHR7wA2zWbc8ogVxDRtXcmR20R14Qwo2VqPLrQ=";
                        checkFlags = [
                          "--skip cli::monitor::external_processors"
                        ];
                      });
                  };
                }
            );


          elf-binary = pkgs.callPackage ./blinky { inherit rustPlatform; };

          inherit (elf-binary.meta) name;

          # Slightly faster build, but we mostly do this to test the feature flag
          qemu-esp32c3 = pkgs.qemu-esp32c3.override { enableTests = false; };

          emulate-script = pkgs.writeShellApplication {
            name = "emulate-${name}";
            runtimeInputs = [
              espflash_3_3_0
              pkgs.esptool
              pkgs.gnugrep
              pkgs.netcat
              qemu-esp32c3
            ];
            text = ''
              # Some sanity checks
              file -b "${elf-binary}/bin/${name}" | grep "ELF 32-bit LSB executable.*UCB RISC-V.*soft-float ABI.*statically linked"
              # Create an image for qemu
              espflash save-image --chip esp32c3 --merge ${elf-binary}/bin/${name} ${name}.bin
              # Get stats
              esptool.py image_info --version 2 ${name}.bin
              # Start qemu in the background, open a tcp port to interact with it
              qemu-system-riscv32 -nographic -monitor tcp:127.0.0.1:44444,server,nowait -icount 3 -machine esp32c3 -drive file=${name}.bin,if=mtd,format=raw -serial file:qemu-${name}.log &
              # Wait a bit
              sleep 3s
              # Kill qemu nicely by sending 'q' (quit) over tcp
              echo q | nc -N 127.0.0.1 44444
              cat qemu-${name}.log
              # Sanity check
              grep "ESP-ROM:esp32c3-api1-20210207" qemu-${name}.log
              # Did we get the expected output?
              grep "Hello world" qemu-${name}.log
            '';
          };

          flash-script = pkgs.writeShellApplication {
            name = "flash-${name}";
            runtimeInputs = [ espflash_3_3_0 ];
            text = ''
              espflash flash --monitor ${elf-binary}/bin/${name}
            '';
          };

          emulate-app = {
            type = "app";
            program = "${lib.getExe emulate-script}";
            meta.description = "Script to emulate '${name}' in QEMU";
          };

          flash-app = {
            type = "app";
            program = "${lib.getExe flash-script}";
            meta.description = "Script to flash '${name}' to hardware";
          };
        in
        {
          packages = {
            inherit elf-binary flash-script emulate-script;
            default = emulate-script;
          };

          checks.default = pkgs.runCommand "qemu-check-${name}" { } ''
            ${lib.getExe emulate-script}
            mkdir "$out"
            cp qemu-${name}.log "$out"
          '';

          devShells.default = pkgs.mkShellNoCC {
            name = "${name}-dev";

            packages = [
              espflash_3_3_0
              pkgs.esptool
              pkgs.gnugrep
              pkgs.netcat
              pkgs.qemu-esp32c3
              toolchain
            ];

            shellHook = ''
              >&2 echo "==> Using toolchain version ${toolchain.version}"
              >&2 echo "    Using cargo version $(cargo --version)"
              >&2 echo "    Using rustc version $(rustc --version)"
              >&2 echo "    Using espflash version $(espflash --version)"
            '';
          };

          apps = {
            default = emulate-app;
            inherit emulate-app flash-app;
          };

          formatter = pkgs.nixfmt-tree;
        }
      );
}
