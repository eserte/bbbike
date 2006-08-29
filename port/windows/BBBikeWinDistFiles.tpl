[%
	SET dirpath = "/tmp/BBBike-" _ VERSION _ "-Windows";
	SET dirpath_length = dirpath.length;
	SET dot = ".";
	SET regexp = "^" _ dot.repeat(dirpath_length) _ "/?";
	USE dir = Directory(dirpath, recurse=1);
	SET files = [];
	PROCESS recurse_dir;

	BLOCK recurse_dir;
	FOREACH file = dir.list;
		IF !file.isdir;
			SET ret = {};
			SET ret.src  = file.path.replace(regexp, "");
			SET ret.src  = ret.src.replace("/", "\\");
			SET ret.dest = file.dir.replace(regexp, "");
			SET ret.dest = ret.dest.replace("/", "\\");
			files.push(ret);
		ELSE;
			PROCESS recurse_dir dir=file;
		END;
	END;
	END;
-%]
