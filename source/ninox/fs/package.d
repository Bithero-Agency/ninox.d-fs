/*
 * Copyright (C) 2023 Mai-Lapyst
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/** 
 * Main module
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module ninox.fs;

// import std.datetime.date;
import std.path : buildPath, buildNormalizedPath, absolutePath;
import std.file : StdDirEntry = DirEntry;
import std.stdio : StdIoFile = File;

/// Baseclass for all exceptions of this package
class NinoxFsException : Exception {
    this(string msg, Throwable nextInChain = null) pure nothrow @nogc @safe {
        super(msg, __FILE__, __LINE__, nextInChain);
    }
}

/// Exception for security issues like path traversal issues for sub-filesystems
class NinoxFsSecurityException : NinoxFsException {
    this(string msg, Throwable nextInChain = null) pure nothrow @nogc @safe {
        super(msg, nextInChain);
    }
}

/// Exception for when a file or directory could not be found
class NinoxFsNotFoundException : NinoxFsException {
    this(string msg, Throwable nextInChain = null) pure nothrow @nogc @safe {
        super(msg, nextInChain);
    }
}

/// Basic interface to interact with a file
interface File {
    /**
     * Reads a chunk of data of the specific size and returns it. Runs syncronously.
     * 
     * Params:
     *   size = the size to read
     *
     * Returns: a buffer with the requested data
     */
    void[] read(int size);

    /**
     * Closes the current file and disallowing any further interaction with it.
     */
    void close();
}

/// Class to represent an File made from a byte array
class ByteArrayFile : File {
    private {
        void[] data;
        int pos = 0;
        bool closed = false;
    }

    this(void[] data) {
        this.data = data;
    }

    void[] read(int size) {
        // TODO: fail if closed
        // TODO: fail if after end

        auto res = this.data[this.pos .. (this.pos + size)];
        this.pos += size;
        return res;
    }

    void close() {
        this.closed = true;
    }
}

/// Enum to represent the kind of a file or path
enum FileKind {
    /// Kind not known; should be treated as an error
    Unknown,

    /// Directory / Folder
    Dir,

    /// Regular file
    File,

    /// Symlink
    SymLink,
}

/// Datastructure to represent the entry in an directory
struct DirEntry {
    private {
        string _name;
        FileKind _kind = FileKind.Unknown;
        ulong _size = 0;
    }

    /**
     * Creates an entry from the raw name, kind and size.
     * 
     * Params:
     *   name = the name of the entry; only full name allowed
     *   kind = the kind of the entry; represnts if its a file, a directory or a symlink
     *   size = the size of the entry; for files, this is the size of the content
     */
    this(string name, FileKind kind, ulong size) {
        this._name = name;
        this._kind = kind;
        this._size = size;
    }

    /**
     * Creates an entry from the entry data from the dland standard library.
     * 
     * Params:
     *   e = a instance of std.file.DirEntry
     */
    this(StdDirEntry e) {
        this._name = e.name();

        if (e.isDir) {
            this._kind = FileKind.Dir;
        }
        else if (e.isFile) {
            this._kind = FileKind.File;
        }
        else if (e.isSymlink) {
            this._kind = FileKind.SymLink;
        }

        this._size = e.size();
    }

    /**
     * Gets the name of the entry.
     * 
     * Returns: the name of the entry.
     */
    @property string name() const return scope {
        return this._name;
    }

    /**
     * Determines weather or not a entry is a directory.
     * 
     * Returns: true if the entry is a directory; false otherwise.
     */
    @property bool isDir() scope {
        return this._kind == FileKind.Dir;
    }

    /**
     * Determines weather or not a entry is a regular file.
     * 
     * Returns: true if the entry is a regular file; false otherwise.
     */
    @property bool isFile() scope {
        return this._kind == FileKind.File;
    }

    /**
     * Determines weather or not a entry is a symlink.
     * 
     * Returns: true if the entry is a symlink; false otherwise.
     */
    @property bool isSymlink() scope {
        return this._kind == FileKind.SymLink;
    }

    /**
     * Gets the size of the entry.
     * 
     * Returns: the size of the entry.
     */
    @property ulong size() scope {
        return this._size;
    }

    // @property SysTime timeCreated() const scope;
    // @property SysTime timeLastAccessed() scope;
    // @property SysTime timeLastModified() scope;
    // @property SysTime timeStatusChanged() const scope;
    // @property uint attributes() scope;
    // @property uint linkAttributes() scope;
}

/**
 * Converts a std.file.DirEntry into a ninox.fs.DirEntry
 * 
 * Params:
 *   e = a instance of std.file.DirEntry to be converted
 * 
 * Returns: a instance of ninox.fs.DirEntry with the data copied from the given std.file.DirEntry
 */
DirEntry toNinoxDirEntry(StdDirEntry e) {
    return DirEntry(e);
}

/**
 * Builds a secure path by first combining the both parameters with buildNormalizedPath and
 * then checking if its still inside the same base by checking the result with startsWith against the 'base' parameter.
 * 
 * Params:
 *   base = the base directory
 *   path = the path to append to the base
 * 
 * Returns: the combined & normalized path from the both parameters
 * 
 * Throws: NinoxFsSecurityException when the resulting path doesnt resides inside the base directory
 */
private string buildSecurePath(string base, string path) {
    import std.string : startsWith;

    string res = buildNormalizedPath(base, path);
    if (!res.startsWith(base)) {
        throw new NinoxFsSecurityException("cannot access parent path from sub-filesystem!");
    }

    return res;
}

/// Basic interface for an Filesystem
interface FS {

    /**
     * Opens the file at the given name and returns a File interface allowing accessing it.
     * 
     * Params:
     *   name = the name of the file to open
     * 
     * Returns: a file interface to accessing the file
     */
    File open(string name);

    /**
     * Reads the content of a directory.
     * 
     * Params:
     *   name = the name of the directory to read
     * 
     * Returns: an array of all entries in the directory
     */
    DirEntry[] readDir(string name);

    /**
     * Reads the whole content of a file.
     * 
     * Params:
     *   name = the name of the file to read
     * 
     * Returns: the content of the file requested as a buffer
     */
    void[] readFile(string name);

    /**
     * Creates an sub-filesystem.
     * 
     * Params:
     *   name = the name of the directory to create a sub-filesystem on
     * 
     * Returns: the sub-filesystem created
     */
    FS sub(string dir);
}

/// A generic filesystem class for implementing sub-filesystems
/// by wrapping a root filesystem and delegating all requests to them prepended with a path.
class SubFS : FS {
    private {
        FS root;
        string path;
    }

    this(FS root, string path) {
        this.root = root;
        this.path = path;

        auto root_as_subfs = cast(SubFS) this.root;
        if (root_as_subfs !is null) {
            this.root = root_as_subfs.root;
            this.path = buildPath(root_as_subfs.path, this.path);
        }
    }

    File open(string name) {
        return this.root.open(buildSecurePath(this.path, name));
    }

    DirEntry[] readDir(string name) {
        return this.root.readDir(buildSecurePath(this.path, name));
    }

    void[] readFile(string name) {
        return this.root.readFile(buildSecurePath(this.path, name));
    }

    FS sub(string dir) {
        return new SubFS(this.root, buildSecurePath(this.path, dir));
    }
}

/// Filesystem onto a folder of the underlaying operating system.
class FolderFs : FS {
    private {
        string path;
    }

    this(string path) {
        import std.file : isDir;
        this.path = buildNormalizedPath(absolutePath(path));
        if (!this.path.isDir) {
            throw new Exception("Cannot create a FolderFS for a non-existing directory!");
        }
    }

    File open(string name) {
        return new ByteArrayFile(this.readFile(name));
    }

    private string buildPath(string name) {
        auto ret = buildSecurePath(this.path, name);
        import std.file : exists;
        if (!exists(ret)) {
            throw new NinoxFsNotFoundException("Could not find file or directory " ~ ret);
        }
        return ret;
    }

    DirEntry[] readDir(string name) {
        import std.file : dirEntries, SpanMode;
        import std.algorithm : map;
        import std.array : array;
        auto entries = dirEntries(this.buildPath(name), SpanMode.shallow);
        return entries.map!( (e) => DirEntry(e) ).array;
    }

    void[] readFile(string name) {
        import std.file : read;
        return read(this.buildPath(name));
    }

    FS sub(string dir) {
        return new FolderFs(this.buildPath(dir));
    }
}

/**
 * Gets a instance of the OS filesystem.
 * 
 * Params:
 *   path = the path of the os filesystem to request
 * 
 * Returns: a instance of ninox.fs.FolderFs for the path requested
 */
FolderFs getOsFs(string path = ".") {
    return new FolderFs(path);
}

/// Entry holding informations for a file of a embedded filesystem
struct EmbeddedFsEntry {
    void[] content;
    FileKind kind;
    ulong size;

    this(string content, FileKind kind) {
        this.content = cast(void[]) content;
        this.kind = kind;
        this.size = this.content.length;
    }

    File open() {
        return new ByteArrayFile(this.content);
    }

    void[] readFile() {
        return content;
    }
}

/// A filesystem that is embedded into the executable
class EmbeddedFs : FS {

    private {
        EmbeddedFsEntry[string] entries;
    }

    this(EmbeddedFsEntry[string] entries) {
        this.entries = entries;
    }

    private bool exists(string name) {
        return (name in this.entries) !is null;
    }

    private void checkExistence(string name) {
        if (!this.exists(name)) {
            throw new NinoxFsNotFoundException("Could not find file or directory " ~ name);
        }
    }

    File open(string name) {
        name = buildNormalizedPath("/", name);
        this.checkExistence(name);
        return this.entries[name].open();
    }

    DirEntry[] readDir(string name) {
        DirEntry[] res;

        name = buildNormalizedPath("/", name);

        foreach (key, val; this.entries) {
            import std.string : startsWith;
            if (key.startsWith(name)) {
                res ~= DirEntry(key, val.kind, val.size);
            }
        }

        return res;
    }

    void[] readFile(string name) {
        name = buildNormalizedPath("/", name);
        this.checkExistence(name);
        return this.entries[name].readFile();
    }

    FS sub(string dir) {
        return new SubFS(this, dir);
    }

}
