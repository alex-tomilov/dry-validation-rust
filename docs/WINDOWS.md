# Windows source-build troubleshooting

Source builds are exercised in an allowed-to-fail Windows CI job with CRuby
3.3. They are not yet a stable Windows support promise; see the
[support matrix](SUPPORT_MATRIX.md) for the current platform status.

Use [RubyInstaller](https://rubyinstaller.org/) with its DevKit and UCRT Ruby.
Open a RubyInstaller development command prompt, then install the UCRT Clang
package that matches Ruby's C runtime:

```powershell
ridk exec pacman -S --needed mingw-w64-ucrt-x86_64-clang
$env:LIBCLANG_PATH = "$env:RI_DEVKIT\ucrt64\bin"
gem install dry-validation-rust --platform ruby
```

The extension selects Rust's `x86_64-pc-windows-gnu` toolchain for a MinGW
Ruby. Install Rust and ensure `cargo` is on `PATH` before installing the gem.

## Common failures

- **`Unable to find libclang` or bindgen errors:** install the UCRT Clang
  package above and set `LIBCLANG_PATH` to `$env:RI_DEVKIT\ucrt64\bin` in the
  same shell that runs `gem install`.
- **Linker or C-runtime mismatch:** use the DevKit's UCRT Clang package, not a
  standalone LLVM installation. Mixing toolchains can select incompatible Ruby
  headers or runtimes.
- **`cargo` is not recognized:** install Rust with rustup, restart the shell,
  and verify `cargo --version`. A source checkout pins the Rust version in
  `rust-toolchain.toml`.
- **Build succeeds but Ruby cannot load the extension:** rerun from a
  RubyInstaller development command prompt so the UCRT runtime and compiler
  tools are on `PATH`.
