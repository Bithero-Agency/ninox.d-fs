module test;

import std.stdio;
import ninox.fs;

void testOsFs() {
	auto fs = getOsFs();

	auto e = fs.readDir(".");
	writeln(e);

	auto c = fs.readFile("./test.txt");
	writeln(cast(string) c);

	auto f = fs.open("./test.txt");
	writeln(cast(string) f.read(5));
	f.close();
}

void testEmbeddFs() {
	auto fs = new EmbeddedFs([
		"/test.txt": EmbeddedFs.Entry(import("./test.txt"), FileKind.File),
	]);

	auto e = fs.readDir(".");
	writeln(e);

	auto c = fs.readFile("./test.txt");
	writeln(cast(string) c);

	auto f = fs.open("./test.txt");
	writeln(cast(string) f.read(5));
	f.close();
}

void testEmbeddFs2() {
	// ninox:embed /*.txt
	auto fs = imported!"test.__embedded_data".fs;

	auto e = fs.readDir(".");
	writeln(e);

	auto c = fs.readFile("./test.txt");
	writeln(cast(string) c);

	auto f = fs.open("./test.txt");
	writeln(cast(string) f.read(5));
	f.close();
}

void testLayerFs() {
	auto fs1 = new EmbeddedFs([
		"/test.txt": EmbeddedFs.Entry("Content of test in fs1", FileKind.File),
		"/1.txt": EmbeddedFs.Entry("fs1 exclusive", FileKind.File),
	]);

	auto fs2 = new EmbeddedFs([
		"/test.txt": EmbeddedFs.Entry("Content of test in fs2", FileKind.File),
		"/2.txt": EmbeddedFs.Entry("fs2 exclusive", FileKind.File),
	]);

	auto layerFs = new LayeredFs(fs1, fs2);

	writeln(cast(string) layerFs.readFile("/test.txt"));
	writeln(cast(string) layerFs.readFile("/1.txt"));
	writeln(cast(string) layerFs.readFile("/2.txt"));
}

void testFsWalk() {
	import ninox.fs.walk;

	auto fs = new EmbeddedFs([
		"/test.txt": EmbeddedFs.Entry("a", FileKind.File),
		"/folder": EmbeddedFs.Entry(FileKind.Dir),
		"/folder/a.txt": EmbeddedFs.Entry("c", FileKind.File),
		"/test1.txt": EmbeddedFs.Entry("b", FileKind.File),
	]);

	fs.walk(".", (FS fs, ref DirEntry entry) {
		import std.stdio;
		writeln("-> ", entry.name);
		return WalkAction.Continue;
	});

}

void main() {
	testOsFs();
	writeln("-------------------------------------");
	testEmbeddFs();
	writeln("-------------------------------------");
	testEmbeddFs2();
	writeln("-------------------------------------");
	testLayerFs();
	writeln("-------------------------------------");
	testFsWalk();
}
