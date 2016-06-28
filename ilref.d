import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.path;
import std.process;
import std.regex;
import std.stdio;
import std.string;

import ae.sys.file;
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

	private string[] fileList()
	{
		auto result = execute(["git", "ls-files"]);
		enforce(result.status == 0);
		return result.output.splitLines().filter!(line => line.endsWith(".il")).array();
	}

	@("Rename a method")
	void renameMethod(string className, string oldName, string newName)
	{
		beforeEdit();

		auto reCall = regex(`\b(` ~ escapeRE(className) ~ `(<.*?>)?::)` ~ escapeRE(oldName) ~ `\b`);
		foreach (fn; fileList())
		{
			auto os = fn.readText();
			auto s = os;
			s = s.replaceAll(reCall, "$1" ~ newName);
			if (fn.baseName == className ~ ".class.il")
				s = s.replace(" " ~ oldName ~ "(", " " ~ newName ~ "(");
			if (os != s)
			{
				stderr.writeln(fn);
				std.file.write(fn, s);
				spawnProcess(["git", "add", fn]).wait();
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
		foreach (fn; fileList())
		{
			auto os = fn.readText();
			auto s = os;
			s = s.replaceAll(reCall, className ~ "::" ~ newName);
			if (fn.baseName == className ~ ".class.il")
			{
				auto lines = s.splitLines();
				bool inDecl;
				foreach (ref l; lines)
					l = l.replaceAll(reDecl, `$1 ` ~ newName);
				s = lines.join("\n");
			}
			if (os != s)
			{
				stderr.writeln(fn);
				std.file.write(fn, s);
				spawnProcess(["git", "add", fn]).wait();
			}
		}

		afterEdit(className ~ "::" ~ oldName ~ " -> " ~ newName);
	}

	@("Rename a class")
	void renameClass(string oldName, string newName)
	{
		beforeEdit();

		auto re1 = regex(`\b(class|valuetype|initobj   |newarr    ) ` ~ escapeRE(oldName) ~ `\b`);
		auto re2 = regex(`\b` ~ escapeRE(oldName) ~ `(::|/|\.class\.il")`);
		auto reDecl = regex(`\b` ~ escapeRE(oldName) ~ `\b`);
		foreach (fn; fileList())
		{
			auto ofn = fn;
			auto os = fn.readText();
			auto s = os;
			s = s.replaceAll(re1, "$1 " ~ newName);
			s = s.replaceAll(re2, newName ~ "$1");

			fn = fn.replace("/" ~ oldName ~ "/", "/" ~ newName ~ "/");
			if (fn != ofn)
				remove(ofn);
			if (fn.dirName.exists && fn.dirName.dirEntries(SpanMode.shallow).empty)
				rmdir(fn.dirName);

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

			if (os != s || fn != ofn)
			{
				if (fn != ofn)
				{
					stderr.writeln(ofn, " -> ", fn);
					spawnProcess(["git", "add", ofn]).wait();
				}
				else
					stderr.writeln(fn);
				ensurePathExists(fn);
				std.file.write(fn, s);
				spawnProcess(["git", "add", fn]).wait();
			}
		}

		afterEdit(oldName ~ " -> " ~ newName);
	}
}

mixin main!(funoptDispatch!ILRef);
