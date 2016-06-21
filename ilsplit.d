import std.algorithm;
import std.path;
import std.stdio;
import std.string;

import ae.utils.funopt;
import ae.utils.main;

void ilsplit(string ilFile)
{
	auto mainFn = ilFile.setExtension(".main.il");
	auto mainFile = File(mainFn, "wb");
	stderr.writeln(mainFn);
	auto outFile = mainFile;
	foreach (l; File(ilFile, "rb").byLine())
	{
		bool end = false;
		if (l.startsWith(".class "))
		{
			auto s = l.chomp();
			s = s.findSplit("<")[0];
			s = s.split[$-1];
			// static const keywords = "public auto ansi sealed beforefieldinit".split();
			// while (keywords.any!(keyword => l.skipOver(keyword ~ " "))) {}
			auto fn = s ~ ".class.il";
			mainFile.writeln(`#include "` ~ fn ~ `"`);
			stderr.writeln(fn);
			outFile = File(ilFile.dirName.buildPath(fn), "wb");
		}
		else
		if (l.startsWith("}"))
			end = true;
		outFile.writeln(l);
		if (end)
			outFile = mainFile;
	}
}

mixin main!(funopt!ilsplit);
