{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  inherit ((builtins.fromTOML (lib.readFile ./Cargo.toml)).package) name;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.lock
      ./Cargo.toml
      ./src
      ./.cargo
    ];
  };

  # Work around https://github.com/NixOS/nixpkgs/pull/435278 - RUSTFLAGS is always set now and overrides .cargo/config.toml.
  # TODO: Keep an eye on
  # https://github.com/NixOS/nixpkgs/pull/464707
  # https://github.com/NixOS/nixpkgs/pull/464992
  # and possibly revert (move back to .cargo/config.toml) or adjust to the new status quo in nixpkgs.
  RUSTFLAGS = [
    "-C"
    "link-arg=-Tlinkall.x"
    # Required to obtain backtraces (e.g. when using the "esp-backtrace" crate.)
    # NOTE: May negatively impact performance of produced code
    "-C"
    "force-frame-pointers"
    # Work around https://github.com/NixOS/nixpkgs/issues/281527 by forcing LLD as the linker:
    #   >   = note: x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '-flavor'
    #   >           x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '--as-needed'; did you mean '-mno-needed'?
    #   >           x86_64-unknown-linux-gnu-gcc: error: unrecognized command-line option '--gc-sections'; did you mean '--data-sections'?
    #   >
    "-C"
    "linker=rust-lld"
  ];

  cargoLock.lockFile = ./Cargo.lock;

  doCheck = false;

  meta.license = lib.licenses.mit;
}
