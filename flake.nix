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

          elf-binary = pkgs.callPackage ./blinky { inherit rustPlatform; };

          inherit (elf-binary.meta) name;

          qemu-esp32c3 =
            (pkgs.qemu-esp32c3.overrideAttrs (
              finalAttrs: prevAttrs: {
                # This patch may be enough (it is the first commit after the tagged release), but we can also just use the latest and greatest
                # patches = prevAttrs.patches or [ ] ++ [
                #   (pkgs.fetchpatch2 {
                #     url = "https://github.com/espressif/qemu/commit/ccdda32084e89108a536dab3a1e1ff83401b8a38.patch?full_index=1";
                #     hash = "sha256-RoBiVOZfUsH2eOEU/c/m6LDGv0wXYf8Vh3xSGGS+WjI=";
                #   })
                # ];
                src = pkgs.fetchFromGitHub {
                  owner = "espressif";
                  repo = "qemu";
                  rev = "c46f68cfd36760d27ea8c5a581c4cdb3165ebd66";
                  hash = "sha256-YcSXEJwxUCfZy5n4rte7R/fKk+OrOutfBf9m8+gXiTg=";
                };
              }
            )).override
              # Without the tests we have a slightly faster build, but we mostly do this to test the feature flag,
              # which is not exercised in the github:SFrijters/nix-qemu-espressif flake .
              { enableTests = false; };

          emulate-script = pkgs.writeShellApplication {
            name = "emulate-${name}";
            runtimeInputs = [
              pkgs.espflash
              pkgs.esptool
              pkgs.gnugrep
              pkgs.netcat
              qemu-esp32c3
            ];
            text = ''
              # Some sanity checks
              file -b "${elf-binary}/bin/${name}" | grep "ELF 32-bit LSB executable.*UCB RISC-V.*soft-float ABI.*statically linked"
              espflash --version
              # Create an image for qemu
              espflash save-image --chip esp32c3 --merge ${elf-binary}/bin/${name} ${name}.bin
              # Get stats
              esptool.py version
              esptool.py image_info --version 2 ${name}.bin
              sleep=10s
              echo "Running qemu in the background for $sleep ..."
              # Start qemu in the background, open a tcp port to interact with it
              qemu-system-riscv32 -nographic -monitor tcp:127.0.0.1:44444,server,nowait -icount 3 -machine esp32c3 -drive file=${name}.bin,if=mtd,format=raw -serial file:qemu-${name}.log &
              # Wait a bit
              sleep "$sleep"
              echo "Killing qemu and analyzing output"
              # Kill qemu nicely by sending 'q' (quit) over tcp
              echo q | nc -N 127.0.0.1 44444
              cat qemu-${name}.log
              # Sanity check
              grep "ESP-ROM:esp32c3-api1-20210207" qemu-${name}.log
              # Did we get the expected output?
              grep "Hello world" qemu-${name}.log
              n=$(grep -c "Hello loop" qemu-${name}.log)
              if [ "$n" -lt 2 ]; then
                echo "Only $n iteration(s) of the loop reported, expected many"
                exit 1
              fi
            '';
          };

          flash-script = pkgs.writeShellApplication {
            name = "flash-${name}";
            runtimeInputs = [ pkgs.espflash ];
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
              pkgs.espflash
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
