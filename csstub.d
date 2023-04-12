/// Stub out method bodies in a C# project.
/// Useful for getting decompiled code to partially compile.
/// Also does some project/solution file edits to make editing/merging easier.

import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.path;
import std.stdio;
import std.string;

import ae.sys.file;
import ae.utils.array;
import ae.utils.funopt;
import ae.utils.main;
import ae.utils.path;
import ae.utils.textout;
import ae.utils.xmllite;
import ae.utils.xmlwriter;

void csstub(string inputDir, string outputDir, string guid="{01234567-89AB-CDEF-0123-456789ABCDEF}")
{
	foreach (de; dirEntries(inputDir, SpanMode.breadth))
	{
		stderr.writeln(de.name);
		auto target = buildPath(outputDir, de.name.absolutePath.relativePath(inputDir.absolutePath).sanitizeFileName());
		if (de.isDir)
			mkdirRecurse(target);
		else
		if (de.extension == ".cs")
		{
			auto output = File(target, "wb");
			auto lines = de.name.readText().split("\n");
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
					if (s.skipOver("where "))
						continue; // Keep declStart value for this line
					else
					if (s.startsWith("new ") || s.canFind(" = new ")) // dictionaries
						continue;
					else
					{
						declStart = false;

						static immutable attributes = ["public", "private", "internal", "static", "sealed"];
						while (attributes.any!(attr => s.skipOver(attr ~ " "))) {}
						static immutable aggregates = ["class", "struct", "enum"];
						if (!aggregates.any!(aggr => s.startsWith(aggr ~ " ")) && (s.endsWith(")") || s.canFind(") where ")))
							declStart = true;
						else
						if (s.isOneOf("get", "set", "add", "remove"))
							declStart = true;
					}
				}
				else
				{
					if (s.among("}", "};") && indent == skipIndent)
					{
						output.writeln("\t".replicate(indent), "#endif");
						output.writeln("\t".replicate(indent), "\tthrow null;");
						skipping = false;
					}

					output.writeln(line);
				}
			}
		}
		else
		if (de.extension == ".sln")
		{
			auto lines = de.name.readText().split("\r\n");
			foreach (ref line; lines)
			{
				// Make GUID stable to facilitate merge
				if (line.startsWith("Project("))
				{
					enforce(line[$-43..$-38] == `", "{`);
					line = line[0..$-39] ~ guid ~ `"`;
				}
				else
				if (line.startsWith("\t\t{"))
				{
					enforce(line[40] == '.');
					line = "\t\t" ~ guid ~ line[40..$];
				}
			}
			std.file.write(target, lines.join("\r\n"));
		}
		else
		if (de.extension == ".csproj")
		{
			auto xml = de.name.readText().xmlParse();
			// xml["Project"]["PropertyGroup", 0]["ProjectGuid"][0].tag = guid;
			// xml["Project"]["ItemGroup", 1].children.sort!((a, b) => a.attributes["Include"] < b.attributes["Include"]);
			// xml["Project"]["ItemGroup", 1].children.each!(child => child.attributes["Include"] = sanitizeFileName(child.attributes["Include"]));

			CustomXmlWriter!(StringBuilder, CustomXmlFormatter!(' ', 2)) writer;
			xml.writeTo(writer);
			std.file.write(target, writer.output.get().replace("\n", "\r\n").strip());
		}
		else
			std.file.write(target, std.file.read(de.name));
	}
}

string sanitizeFileName(string fn)
{
	return fn.replace(" ", "_");
}

mixin main!(funopt!csstub);
