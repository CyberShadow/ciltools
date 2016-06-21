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
		spawnProcess(["git", "commit", "-m", commitMessage]).wait();
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
				spawnProcess(["git", "add", de.name]).wait();
			}
		}

		afterEdit(className ~ "::" ~ oldName ~ " -> " ~ newName);
	}

	@("Rename a field")
	void renameField(string className, string oldName, string newName)
	{
		beforeEdit();

		auto reCall = regex(`\b` ~ escapeRE(className ~ "::" ~ oldName) ~ `\b`);
		auto reDecl = regex(`^(\s*\.field .*) ` ~ escapeRE(oldName) ~ `$`);
		foreach (de; dirEntries("", "*.il", SpanMode.depth))
		{
			auto os = de.readText();
			auto s = os;
			s = s.replaceAll(reCall, className ~ "::" ~ newName);
			if (de.baseName == className ~ ".class.il")
			{
				auto lines = s.splitLines();
				bool inDecl;
				foreach (ref l; lines)
					l = l.replaceAll(reDecl, `$1 ` ~ newName);
				s = lines.join("\n");
			}
			if (os != s)
			{
				stderr.writeln(de.name);
				std.file.write(de.name, s);
				spawnProcess(["git", "add", de.name]).wait();
			}
		}

		afterEdit(className ~ "::" ~ oldName ~ " -> " ~ newName);
	}

	@("Rename a class")
	void renameClass(string oldName, string newName)
	{
		beforeEdit();

		auto re1 = regex(`\bclass ` ~ escapeRE(oldName) ~ `\b`);
		auto re2 = regex(`\b` ~ escapeRE(oldName) ~ `::`);
		auto re3 = regex(`#include "` ~ escapeRE(oldName) ~ `.class.il"`);
		auto reDecl = regex(`\b` ~ escapeRE(oldName) ~ `\b`);
		foreach (de; dirEntries("", "*.il", SpanMode.depth))
		{
			auto fn = de.name;
			auto os = de.readText();
			auto s = os;
			s = s.replaceAll(re1, "class " ~ newName);
			s = s.replaceAll(re2, newName ~ "::");
			s = s.replaceAll(re3, `#include "` ~ newName ~  `.class.il"`);

			if (fn.baseName == oldName ~ ".class.il")
			{
				auto lines = s.splitLines();
				bool inDecl;
				foreach (ref l; lines)
				{
					if (l.strip().startsWith(".class "))
						inDecl = true;
					if (inDecl && l.match(reDecl))
					{
						l = l.replaceAll(reDecl, newName);
						inDecl = false;
					}
				}
				s = lines.join("\n");

				remove(fn);
				fn = fn.dirName.buildPath(newName ~ ".class.il");
			}

			if (os != s)
			{
				if (fn != de.name)
				{
					stderr.writeln(de.name, " -> ", fn);
					spawnProcess(["git", "add", de.name]).wait();
				}
				else
					stderr.writeln(fn);
				std.file.write(fn, s);
				spawnProcess(["git", "add", fn]).wait();
			}
		}

		afterEdit(oldName ~ " -> " ~ newName);
	}
}

mixin main!(funoptDispatch!ILRef);
