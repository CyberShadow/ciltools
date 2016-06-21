import std.algorithm;
import std.file;
import std.path;
import std.stdio;
import std.string;

import ae.utils.funopt;
import ae.utils.main;

struct ILRef
{
static:
	@("Rename a method")
	void renameMethod(string className, string oldName, string newName)
	{
		foreach (de; dirEntries("", "*.il", SpanMode.depth))
		{
			auto os = de.readText();
			auto s = os;
			s = s.replace(className ~ "::" ~ oldName, className ~ "::" ~ newName);
			if (de.baseName == className ~ ".class.il")
				s = s.replace(" " ~ oldName ~ "(", " " ~ newName ~ "(");
			if (os != s)
			{
				stderr.writeln(de.name);
				std.file.write(de.name, s);
			}
		}
	}
}

mixin main!(funoptDispatch!ILRef);
