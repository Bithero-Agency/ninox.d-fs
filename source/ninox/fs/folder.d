/*
 * Copyright (C) 2023-2024 Mai-Lapyst
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
 * Module to hold `FolderFs`; a filesystem used to wrap the OS's filesystem.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023-2024 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.fs.folder;

import ninox.fs;

import std.path : buildNormalizedPath, absolutePath, relativePath;

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
        auto path = this.buildPath(name);
        auto entries = dirEntries(path, SpanMode.shallow, false);
        return entries.map!((e) {
            auto r = DirEntry(e);
            r._name = relativePath(r._name, path);
            return r;
        }).array;
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
