with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    clang
    xxd
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [

  ];
}
