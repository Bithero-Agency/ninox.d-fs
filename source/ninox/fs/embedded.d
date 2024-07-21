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
 * Module to hold `EmbeddedFs`; a filesystem used to embed files in the compilation step of an dlang program.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023-2024 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.fs.embedded;

import ninox.fs;

import std.path : buildNormalizedPath;

/// Entry holding informations for a file of a embedded filesystem
struct EmbeddedFsEntry {
    void[] content;
    FileKind kind;
    ulong size;

    this(FileKind kind) {
        this.content = null;
        this.kind = kind;
        this.size = -1;
    }

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
            import std.path : dirName, baseName;
            if (key.dirName == name) {
                res ~= DirEntry(key.baseName, val.kind, val.size);
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
