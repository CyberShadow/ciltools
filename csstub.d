/// Stub out method bodies in a C# project.
/// Useful for getting decompiled code to partially compile.

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.stdio;
import std.string;

import ae.sys.file;
import ae.utils.funopt;
import ae.utils.main;
import ae.utils.path;

void csstub(string inputDir, string outputDir)
{
	foreach (de; dirEntries(inputDir, SpanMode.depth))
	{
		stderr.writeln(de.name);
		auto target = de.name.rebasePath(inputDir, outputDir);
		if (de.isDir)
			mkdirRecurse(target);
		else
		if (de.extension == ".cs")
		{
			auto output = File(target, "wb");
			auto lines = de.name.readText().split("\r\n");
			int skipIndent; bool skipping, declStart;
			foreach (i, line; lines)
			{
				auto s = line;
				int indent = 0;
				while (s.skipOver("\t")) indent++;

				if (!skipping)
				{
					output.writeln(line);

					if (s == "{")
					{
						if (declStart)
						{
							output.writeln("\t".replicate(indent), "#if false");
							skipping = true;
							skipIndent = indent;
						}
					}
					else
					if (declStart)
						declStart = false;
					else
					{
						static immutable attributes = ["public", "private", "internal", "static", "sealed"];
						while (attributes.any!(attr => s.skipOver(attr ~ " "))) {}
						static immutable aggregates = ["class", "enum"];
						if (attributes.any!(attr => s.startsWith(attr ~ " ")))
							declStart = true;
					}
				}
				else
				{
					output.writeln(line);

					if (s == "}" && indent == skipIndent)
					{
						output.writeln("\t".replicate(indent), "#endif");
						output.writeln("\t".replicate(indent), "throw null;");
						skipping = false;
					}
				}
			}
			// ...
		}
		else
			copy(de.name, target);
	}
}

mixin main!(funopt!csstub);
