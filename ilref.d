import std.algorithm;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;
import std.process;

import ae.utils.funopt;
import ae.utils.main;
import ae.utils.regex;

struct ILRef
{
static:
	private void beforeEdit()
	{
		spawnProcess(["git", "stash", "save"]).wait();
	}

	private void afterEdit(string commitMessage)
	{
		spawnProcess(["git", "commit", "-am", commitMessage]).wait();
	}

	@("Rename a method")
	void renameMethod(string className, string oldName, string newName)
	{
		beforeEdit();

		auto reCall = regex(`\b` ~ escapeRE(className ~ "::" ~ oldName) ~ `\b`);
		foreach (de; dirEntries("", "*.il", SpanMode.depth))
		{
			auto os = de.readText();
			auto s = os;
			s = s.replaceAll(reCall, className ~ "::" ~ newName);
			if (de.baseName == className ~ ".class.il")
				s = s.replace(" " ~ oldName ~ "(", " " ~ newName ~ "(");
			if (os != s)
			{
				stderr.writeln(de.name);
				std.file.write(de.name, s);
			}
		}

		afterEdit(className ~ "::" ~ oldName ~ " -> " ~ newName);
	}
}

mixin main!(funoptDispatch!ILRef);
