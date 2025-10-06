with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    clang
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [

  ];
}
