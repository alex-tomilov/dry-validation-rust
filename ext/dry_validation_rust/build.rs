fn main() {
    if let Ok(libdir) = std::env::var("DEP_RB_RBCONFIG_LIBDIR") {
        println!("cargo:rustc-link-arg=-Wl,-rpath,{}", libdir);
    }
}
