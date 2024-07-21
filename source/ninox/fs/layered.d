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
 * Module to hold `LayeredFs`; a filesystem that layers other filesystems antop of each other and
 * delegates calls to them.
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2024 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module ninox.fs.layered;

import ninox.fs;

/// A layered filesystem that delegates calls to different other filesystems
class LayeredFs : FS {

    private {
        FS[] layers;
    }

    this(FS[] layers...) {
        this.layers = layers;
    }

    private template rethrowLayerException() {
        enum rethrowLayerException = `
            import std.conv : to;
            throw new NinoxFsException("Layer " ~ typeid(cast(Object) layer).to!string ~ " threw exception", th);
        `;
    }

    File open(string name) {
        foreach (ref layer; this.layers) {
            try {
                return layer.open(name);
            } catch (NinoxFsNotFoundException e) {
                continue;
            } catch (Throwable th) {
                mixin(rethrowLayerException!());
            }
        }
        throw new NinoxFsNotFoundException("Could not find file or directory " ~ name);
    }

    DirEntry[] readDir(string name) {
        foreach (ref layer; this.layers) {
            try {
                return layer.readDir(name);
            } catch (NinoxFsNotFoundException e) {
                continue;
            } catch (Throwable th) {
                mixin(rethrowLayerException!());
            }
        }
        throw new NinoxFsNotFoundException("Could not find file or directory " ~ name);
    }

    void[] readFile(string name) {
        foreach (ref layer; this.layers) {
            try {
                return layer.readFile(name);
            } catch (NinoxFsNotFoundException e) {
                continue;
            } catch (Throwable th) {
                mixin(rethrowLayerException!());
            }
        }
        throw new NinoxFsNotFoundException("Could not find file or directory " ~ name);
    }

    FS sub(string dir) {
        return new SubFS(this, dir);
    }

}
