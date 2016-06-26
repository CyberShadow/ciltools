// Simple preprocessor for #include directives.
// ilasm already supports #include, but its handling of relative paths is broken -
// it always looks relative to the current / main file directory, not relative to
// the current #include-d file.

import std.algorithm;
import std.path;
import std.stdio;
import std.string;

import ae.utils.funopt;
import ae.utils.main;

void ilmerge(string ilFile)
{
	foreach (l; File(ilFile, "rb").byLine())
		if (l.startsWith(`#include `))
			ilmerge(ilFile.dirName.buildPath(l.split('"')[1]));
		else
			writeln(l);
}

mixin main!(funopt!ilmerge);
