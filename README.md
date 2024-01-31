# nix-qemu-espressif-rust-example

This is an example / test for https://github.com/SFrijters/nix-qemu-espressif; it is kept out of that repository to keep that one as lean as possible.

As an example we compile a simple 'blinking LED' Rust code based on https://github.com/esp-rs/no_std-training/tree/main/intro/blinky for an ESP32C3 chip and run it on qemu.

```console
$ nix flake check -L
```

This flake also provides the following apps:

* `nix run .#emulate` (default app) to run the emulation test script directly.
* `nix run .#flash` to flash the compiled code to a physical device.


## Further reading

* https://n8henrie.com/2023/09/compiling-rust-for-the-esp32-with-nix/
* https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32c3/README.md
