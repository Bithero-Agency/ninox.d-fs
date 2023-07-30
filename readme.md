# ninox.d-fs

This package provides an abstraction layer over read-access to the filesystem, with additional support for embedded filesystems.

## License

The code in this repository is licensed under AGPL-3.0-or-later; for more details see the `LICENSE` file in the repository.

## Library

### Filesystems implemented

- `ninox.fs.FolderFs`: a filesystem wrapper that is "mounted" onto a folder of the OS's native filesystem. Use `getOsFs` to simply get an instance of it (default is the cwd).
- `ninox.fs.EmbeddedFs`: a filesystem that supports reading embedded data; mostly used via the embedding source generation (see below).

### The `ninox.fs.FS` interface

Each filesystem abstraction implements 4 actions:
- `File open(string name);`: opens the file specified via `name` and returns a `ninox.fs.File` handle
- `DirEntry[] readDir(string name);`: reads the content of a dir specified via `name` and returns all entries in it as an array of `ninox.fs.DirEntry`.
- `void[] readFile(string name);`: reads the content of a file fully specified via `name`; returns a `void[]` that represents the buffer of the data read.
- `FS sub(string dir);`: a special action: with this the package allows you to create an FS that is restricted to a portion of the initial filesystem.

## Embedding

To embed files and whole directories into your applications you need to do the following:
- edit your project's `dub.json`
    - add a dependency for `ninox-d_fs`
    - add the package root to the `stringImportPaths`, i.e. `"stringImportPaths": [ "." ]`
    - add `dub run ninox-d_fs -- <package name>` to `preGenerateCommands`

- use following code snippet in your project: `imported!"<package name>.__embedded_data".xxx`
    The `xxx` part is freely chooseable, but needs to be unique for your project.

- to add files and or folders to the embedded fs, add comments above the line where you used the snippet containing following directive: `ninox:embed <glob>`. The glob needs to begin with a `/` to refer to the package root. Use as many lines as needed, but do not skip a line, since that will break the detection!

When now running and/or building the project, ninox.d-fs should automatically generate a sourcefile named `__embedded_data.d` which contains the code for your embedded filesystem.
