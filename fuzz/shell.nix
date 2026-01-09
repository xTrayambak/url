with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    clang
    libllvm
    xxd
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [

  ];
}
