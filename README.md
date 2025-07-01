# nix-qemu-esp32c3-rust-example

[![GitHub CI](https://github.com/SFrijters/nix-qemu-esp32c3-rust-example/actions/workflows/nix-flake-check.yml/badge.svg)](https://github.com/SFrijters/nix-qemu-esp32c3-rust-example/actions/workflows/nix-flake-check.yml) [![GitLab CI](https://gitlab.com/SFrijters/nix-qemu-esp32c3-rust-example/badges/master/pipeline.svg?key_text=GitLab+CI)](https://gitlab.com/SFrijters/nix-qemu-esp32c3-rust-example/-/commits/master)

This is an example / test for https://github.com/SFrijters/nix-qemu-espressif; it is kept out of that repository to keep it as lean as possible.

## Usage

As an example we compile a simple 'blinking LED' Rust code based on [an example in esp-hal](https://github.com/esp-rs/esp-hal/blob/fbc57542a8f4b71e30f0dcea4045c508ce753139/examples/src/bin/blinky.rs) for an ESP32C3 chip and run it on QEMU:

* `nix flake check -L`

This command is also run in the GitHub action.

This flake also provides the following apps:

* `nix run .#emulate` (default app) to run the emulation test script directly.
* `nix run .#flash` to flash the compiled code to a physical device.

And a development shell via:

* `nix develop`

Inside the development shell, we can also use `cargo` directly to build the binary:

```console
$ nix develop
$ cd blinky && cargo build --release
```

Finally, there are three package outputs:

* `nix build .#elf-binary` builds only the ELF binary file.
* `nix build .#emulate-script` (default package) builds a script to run the emulation test.
* `nix build .#flash-script` builds a wrapper script to flash the binary to a physical device using [espflash](https://github.com/esp-rs/espflash).

## Physical test

The code has been tested on a [Seeed Studio XIAO ESP32C3](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/). The GPIO10 pin corresponds to the D10 pin as marked on the board.

## Known issues

This example code works around [a linker issue in nixpkgs](https://github.com/NixOS/nixpkgs/issues/281527) in [blinky/.cargo/config.toml](blinky/.cargo/config.toml). Please refer to the linked issue for details and please suggest a better/permanent fix if you know of one! We also may need to keep an eye on https://github.com/NixOS/nixpkgs/pull/389204 .

## Further reading

* https://github.com/espressif/qemu
* https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32c3/README.md
* https://github.com/esp-rs/esp-hal/
* https://github.com/esp-rs/no_std-training/
* https://n8henrie.com/2023/09/compiling-rust-for-the-esp32-with-nix/
