{
  lib,
  rustPlatform,
  pkgsCross,
}:

rustPlatform.buildRustPackage {
  inherit ((builtins.fromTOML (builtins.readFile ./Cargo.toml)).package) name;
  src = lib.cleanSource ./.;
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
  doCheck = false;

  # Work around https://github.com/NixOS/nixpkgs/issues/281527 by forcing LLD as the linker:
  #   >   = note: x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '-flavor'
  #   >           x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '--as-needed'; did you mean '-mno-needed'?
  #   >           x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '--gc-sections'; did you mean '--data-sections'?
  #   >
  # This overrides CARGO_TARGET_RISCV32IMC_UNKNOWN_NONE_ELF_LINKER
  # which is set in https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/lib/default.nix
  cargoBuildFlags = [
    "--config target.riscv32imc-unknown-none-elf.linker='${pkgsCross.pkgsBuildHost.llvmPackages.bintools}/bin/${pkgsCross.stdenv.cc.targetPrefix}ld.lld'"
  ];
}
