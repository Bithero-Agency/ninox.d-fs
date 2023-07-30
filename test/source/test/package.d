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
		"/test.txt": EmbeddedFsEntry(import("./test.txt"), FileKind.File),
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

void main() {
	testOsFs();
	writeln("-------------------------------------");
	testEmbeddFs();
	writeln("-------------------------------------");
	testEmbeddFs2();
}
