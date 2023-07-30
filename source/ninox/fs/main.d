module ninox.fs.main;

import std.stdio;
import std.getopt;
import std.process : environment;

immutable help_banner = (
`Usage: ninox-d_fs:srcgen <options>

Options:
`);

void printUsage() {
    writeln("Usage: ninox-d_fs:srcgen <options>");
    writeln("");
    writeln("Available options:");
    writeln("  --help\t\tPrints this help");
    writeln("  --verbose\t\tEnables verbose printing");
    writeln("  --module=MODULE\tAdds an module to the search for embedded filesystems");
    writeln("  --include=PATH\t");
}

/// The package name provided by the cli call
string package_name = null;

/// The module name, either the default '__embedded_data' or a custom one set by the cli option '--module'
string module_name = "__embedded_data";

// /// The source directory to search in, will be found by looking into the info dumped by 'dub describe'
// string source_dir = null;

/// The package root directory, provided by dubs env variable 'DUB_PACKAGE_DIR'
string root_dir = null;

string[] source_files = null;

/// Verbose logging flag
bool verbose = false;

string genDModule(string timestamp) {
    string code =
`
/**
 * Generated at `~timestamp~`
 * by ninox.d-fs
 * $(LINK https://github.com/Bithero-Agency/ninox.d-fs)
 */
module `~package_name~`.`~module_name~`;

import ninox.fs;

`
    ;

    import std.regex : regex, matchAll, matchFirst;
    import std.file : readText;
    import std.string : splitLines;

    auto re = regex( "imported!\"" ~ package_name ~ "." ~ module_name ~ "\".(\\w+)" );
    auto re_directive = regex("ninox:embed (.*)");

    string[] already_used_names;

    // search through the whole source tree to find all embedded filesystems
    foreach (source_file; source_files) {
        writeln("Info ninox.d-fs: scanning ", source_file, " ...");

        auto matches = matchAll(readText(source_file), re);
        foreach (match; matches) {

            import std.algorithm.searching : canFind;
            if (canFind(already_used_names, match[1])) {
                throw new Exception("Cannot use the name '" ~ match[1] ~ "' twice!");
            }

            string[] specs = [];

            // search for "ninox:embed" directives before the match...
            {
                auto lines = match.pre().splitLines();
                foreach_reverse (line; lines[0 .. $-1]) {
                    auto d_match = matchFirst(line, re_directive);
                    if (d_match) {
                        specs ~= d_match[1];
                        continue;
                    }
                    break;
                }
            }

            writeln("Info ninox.d-fs: -> found '", match[1], "' with ", specs);

            code ~= "static EmbeddedFs " ~ match[1] ~ " = null;\n";
            code ~= "shared static this() {\n";
            code ~= "    " ~ match[1] ~ " = new EmbeddedFs([\n";

            // go through the specs and build the entries for the embeded filesystem
            foreach (spec; specs) {
                string base = "";
                if (spec[0] == '/') {
                    // root is the source of the current package
                    spec = root_dir ~ spec;
                    base = root_dir;
                }
                else {
                    // TODO
                    throw new Exception("Non-root paths aren't allowed for now!");
                }

                import std.path : buildNormalizedPath, relativePath;
                spec = buildNormalizedPath(spec);

                import std.string : startsWith;
                if (!startsWith(spec, root_dir)) {
                    throw new Exception("Tried to embed a file outside of the packages root directory!");
                }

                import glob : glob;
                foreach (file; glob(spec)) {
                    string fpath = "/" ~ relativePath(file, base);
                    string ipath = relativePath(file, root_dir);

                    writeln("Info ninox.d-fs:    include: ", file, " as: ", fpath);
                    code ~= "        \"" ~ fpath ~ "\": EmbeddedFsEntry(import(\"" ~ ipath ~ "\"), FileKind.File),\n";
                }
            }

            code ~= "    ]);\n";
            code ~= "}\n\n";

            already_used_names ~= match[1];
        }
    }

    return code;
}

void addToIgnoreFile(string ignorefile, string path) {
    import std.file : exists, isFile, readText;
    import std.path : buildNormalizedPath;
    import std.algorithm.searching : canFind;

    ignorefile = buildNormalizedPath(root_dir, ignorefile);

    if (!exists(ignorefile)) {
        return;
    }

    if (!isFile(ignorefile)) {
        return;
    }

    auto content = readText(ignorefile);
    if (!content.canFind(path)) {
        auto f = File(ignorefile, "a+");
        scope(exit) f.close();

        f.rawWrite("\n");
        f.rawWrite(path);
        f.rawWrite("\n");
    }
}

int main(string[] args) {
    import std.string : split;
    import std.path : buildNormalizedPath, dirSeparator, dirName;
    import std.string : replace;
    import std.file : exists, isDir;
    import std.range : empty;
    import std.datetime : Clock;

    immutable usage_hint = "For usage, run: ninox-d_fs --help";

    try {
        auto help_info = getopt(
            args,
            "module", &module_name,
            "v|verbose", &verbose,
        );

        if (help_info.helpWanted) {
            defaultGetoptPrinter(help_banner, help_info.options);
            return false;
        }
    }
    catch(GetOptException e) {
        stderr.writeln(e.msg);
        stderr.writeln(usage_hint);
        return 1;
    }

    if (!(args.length == 2 && !args[1].empty)) {
        stderr.writeln("Missing package name");
        stderr.writeln(usage_hint);
        return 1;
    }
    package_name = args[1];

    // get the import paths given to us by dub's preGenerateCommands invokation
    auto import_paths = split(environment["IMPORT_PATHS"], " ");

    // also get the source files given to us by dub's preGenerateCommands invokation
    source_files = split(environment["SOURCE_FILES"], " ");

    root_dir = environment["DUB_PACKAGE_DIR"];
    writeln("Info ninox.d-fs: using ", root_dir, " as package root");

    string src_dir = import_paths[0];
    writeln("Info ninox.d-fs: using ", src_dir, " as source directory");

    auto output_path = buildNormalizedPath(src_dir, package_name.replace(".", dirSeparator), module_name ~ ".d");
    writeln("Info ninox.d-fs: using ", output_path, " as output file");

    auto output_dir = dirName(output_path);
    if (!exists(output_dir)) {
        stderr.writeln("Output directory doesn't exist: ", output_dir);
        stderr.writeln(usage_hint);
        return 1;
    }
    if (!isDir(output_dir)) {
        stderr.writeln("Output directory isn't a directory: ", output_dir);
        stderr.writeln(usage_hint);
        return 1;
    }

    auto now = Clock.currTime;

    auto resultDcode = genDModule(now.toString());

    import std.file : write;
    write(output_path, resultDcode);

    import std.path : relativePath;
    auto rel_output_path = relativePath(output_path, root_dir);

    addToIgnoreFile(".gitignore", rel_output_path);
    addToIgnoreFile(".hgignore", rel_output_path);

    return 0;
}