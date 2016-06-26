import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.stdio;
import std.string;

import ae.sys.file;
import ae.utils.funopt;
import ae.utils.main;

void ilsplit(bool splitMethods, string ilFile)
{
	static struct IncludeFile { File f; int indent; }

	IncludeFile[] stack;
	void pushFile(string fn, int indent = -1)
	{
		if (indent != -1)
		{
			stack[$-1].f.writeln(`#include "` ~ fn ~ `"`);
			stack[$-1].f.flush();
		}
		stderr.writeln(fn);
		auto path = ilFile.dirName.buildPath(fn);
		ensurePathExists(path);
		stack ~= IncludeFile(File(path, "wb"), indent);
	}

	pushFile(ilFile.setExtension(".main.il"));

	auto lines = readText(ilFile).split("\r\n");

	foreach (i, line; lines)
	{
		auto s = line;
		int indent;
		while (s.skipOver(" ")) indent++;

		bool end = false;

		if (s.startsWith("."))
		{
			auto keyword = s.findSplit(" ")[0];
			auto declaration = s;
			auto prefix = " ".replicate(indent + keyword.length + 1);
			for (auto j = i+1; ; j++)
			{
				if (j == lines.length)
				{
					declaration = null;
					break;
				}
				else
				if (lines[j].startsWith(prefix))
					declaration ~= " " ~ lines[j].strip();
				else
				if (lines[j].strip() == "{")
					break;
				else
				{
					declaration = null;
					break;
				}
			}

			switch (keyword)
			{
				case ".class":
				{
					auto name = declaration.findSplit(" extends ")[0].findSplit("<")[0].split()[$-1];
					// static const keywords = "public auto ansi sealed beforefieldinit".split();
					// while (keywords.any!(keyword => l.skipOver(keyword ~ " "))) {}
					pushFile(name ~ ".class.il", indent);
					break;
				}
				case ".method":
					if (splitMethods)
					{
						auto name = declaration.findSplit("(")[0].split()[$-1];
						pushFile(name ~ ".class.il", indent);
					}
					break;
				default:
					break;
			}
		}
		else
		if (s.startsWith("}") && indent == stack[$-1].indent)
			end = true;

		stack[$-1].f.writeln(line);
		if (end)
		{
			stack[$-1].f.close();
			stack = stack[0..$-1];
		}
	}
}

mixin main!(funopt!ilsplit);
