import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;

import ae.sys.file;
import ae.utils.array;
import ae.utils.funopt;
import ae.utils.main;
import ae.utils.text;

void ilsplit(bool splitMethods, string ilFile)
{
	static struct IncludeFile { File f; string name; int indent; }

	IncludeFile[] stack;
	bool[string] sawPath;
	void pushFile(string name, string type, int indent = -1)
	{
		string path, fn, suffix;
		while (true)
		{
			fn = name ~ "." ~ type ~ suffix ~ ".il";
			path = buildPath(stack.map!(f => f.name).chain(fn.only));
			if (path !in sawPath)
				break;
			suffix ~= "_";
		}
		sawPath[path] = true;
		if (indent != -1)
		{
			stack[$-1].f.writeln(" ".replicate(indent), `#include "` ~ (stack.length ? stack[$-1].name ~ "/" : "") ~ fn ~ `"`);
			stack[$-1].f.flush();
		}
		stderr.writeln(path);
		path = ilFile.dirName.buildPath(path);
		ensurePathExists(path);
		enforce(!path.exists, "File already exists: " ~ path);
		stack ~= IncludeFile(File(path, "wb"), name, indent);
	}

	pushFile(ilFile.baseName.stripExtension(), "main");

	auto lines = readText(ilFile).splitAsciiLines();

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
					auto name = declaration.findSplit(" extends ")[0];
					if (name.split()[$-1].startsWith("'<"))
						name = name.findSplit(">")[2].split()[$-1];
					else
						name = name.findSplit("<")[0].split()[$-1];
					// static const keywords = "public auto ansi sealed beforefieldinit".split();
					// while (keywords.any!(keyword => l.skipOver(keyword ~ " "))) {}
					pushFile(name, "class", indent);
					break;
				}
				case ".method":
					if (splitMethods)
					{
						auto name = declaration
							.findSplit("(")[0]
							.replace("<", "(")
							.replace(">", ")")
							.split()[$-1]
						;
						scope(failure) stderr.writeln(declaration);
						auto args = declaration
							.split("(")[$-1]
							.findSplit(")")[0]
							.splitEmpty(", ")
							.map!(arg => arg
							      .findSplit("<")[0]
							      .split()[$-2]
							      .split(".")[$-1]
							);
						name ~= "(" ~ args.join(",") ~ ")";
						pushFile(name, "method", indent);
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
