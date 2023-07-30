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

interface File {
    void[] read(int size);
    void close();
}

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

enum FileKind {
    Unknown,
    Dir,
    File,
    SymLink,
}

struct DirEntry {
    private {
        string _name;
        FileKind _kind = FileKind.Unknown;
        ulong _size = 0;
    }

    this(string name, FileKind kind, ulong size) {
        this._name = name;
        this._kind = kind;
        this._size = size;
    }

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

    @property string name() const return scope {
        return this._name;
    }

    @property bool isDir() scope {
        return this._kind == FileKind.Dir;
    }

    @property bool isFile() scope {
        return this._kind == FileKind.File;
    }

    @property bool isSymlink() scope {
        return this._kind == FileKind.SymLink;
    }

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

DirEntry toNinoxDirEntry(StdDirEntry e) {
    return DirEntry(e);
}

private string buildSecurePath(string base, string path) {
    import std.string : startsWith;

    string res = buildNormalizedPath(base, path);
    if (!res.startsWith(base)) {
        throw new Exception("Security exception: cannot access parent path from sub-filesystem!");
    }

    return res;
}

interface FS {
    File open(string name);
    DirEntry[] readDir(string name);
    void[] readFile(string name);
    FS sub(string dir);
}

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

    DirEntry[] readDir(string name) {
        import std.file : dirEntries, SpanMode;
        import std.algorithm : map;
        import std.array : array;
        auto entries = dirEntries(buildSecurePath(this.path, name), SpanMode.shallow);
        return entries.map!( (e) => DirEntry(e) ).array;
    }

    void[] readFile(string name) {
        import std.file : read;
        return read(buildSecurePath(this.path, name));
    }

    FS sub(string dir) {
        return new FolderFs(buildSecurePath(this.path, dir));
    }
}

FolderFs getOsFs(string path = ".") {
    return new FolderFs(path);
}

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
            throw new Exception("Could not find file or directory in EmbeddedFs");
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
