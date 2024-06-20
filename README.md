# nix-qemu-esp32c3-rust-example

[![nix flake check](https://github.com/SFrijters/nix-qemu-esp32c3-rust-example/actions/workflows/qemu-check-blinky.yml/badge.svg)](https://github.com/SFrijters/nix-qemu-esp32c3-rust-example/actions/workflows/qemu-check-blinky.yml)

This is an example / test for https://github.com/SFrijters/nix-qemu-espressif; it is kept out of that repository to keep it as lean as possible.

## Usage

As an example we compile a simple 'blinking LED' Rust code based on [an example in esp-hal](https://github.com/esp-rs/esp-hal/blob/v0.18.0/examples/src/bin/blinky.rs) for an ESP32C3 chip and run it on QEMU:

* `nix flake check -L`

This command is also run in the GitHub action.

This flake also provides the following apps:

* `nix run .#emulate` (default app) to run the emulation test script directly.
* `nix run .#flash` to flash the compiled code to a physical device.

And a development shell via:

* `nix develop`

## Physical test

The code has been tested on a [Seeed Studio XIAO ESP32C3](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/). The GPIO10 pin corresponds to the D10 pin as marked on the board.

## Further reading

* https://github.com/espressif/qemu
* https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32c3/README.md
* https://github.com/esp-rs/esp-hal/
* https://github.com/esp-rs/no_std-training/
* https://n8henrie.com/2023/09/compiling-rust-for-the-esp32-with-nix/
