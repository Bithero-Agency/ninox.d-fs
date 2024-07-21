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
 * Module to hold `SubFS`; a filesystem used to wrap a subfolder of an filesystem.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023-2024 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.fs.sub;

import ninox.fs;

import std.path : buildPath;

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
