/*
 * Copyright (C) 2024 Mai-Lapyst
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
 * Module to hold fs walking code.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2024 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.fs.walk;

import ninox.fs;

import ninox.std.callable;
import ninox.std.traits : RefT;

/// Return type for the `action` callback for `walk(FS, ...)`.
enum WalkAction {
    /// Continue normal walking.
    Continue,

    /// Skip subtree (of folders), but continue otherwise like normal.
    SkipSubTree,

    /// Stop walking entirely.
    Stop,
}

alias WalkFunc = Callable!(WalkAction, FS, RefT!DirEntry);

/** 
 * Walks a filesystem, starting in `startDir`. Calls for every entry the `action` callback.
 * 
 * Params:
 *   fs = The filesystem to use.
 *   startDir = The starting directory.
 *   action = The callback to call for each found entry.
 * 
 * Returns: `true` if successfull; `false` if the callback has returned `WalkAction.Stop`.
 */
bool walk(FS fs, string startDir, WalkFunc action) {
    auto entries = fs.readDir(startDir);
    foreach (ref entry; entries) {
        final switch (action(fs, entry)) {
            case WalkAction.Continue:
                if (entry.isDir) {
                    import std.path : buildPath;
                    if (!walk(fs, buildPath(startDir, entry.name), action)) {
                        return false;
                    }
                }
                break;
            case WalkAction.SkipSubTree:
                continue;
            case WalkAction.Stop:
                return false;
        }
    }
    return true;
}

/// ditto
pragma(inline) bool walk(FS fs, string startDir, WalkAction delegate(FS fs, ref DirEntry entry) action) {
    return walk(fs, startDir, WalkFunc(action));
}
