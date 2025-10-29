// NOTE(blackedout): Modified from https://ziglang.org/learn/build-system/#project-tools (2025-10-29)
// This program should not be used for many occurrences of patterns (with short length) as each pattern invokes two file writes.

const std = @import("std");

const usage =
	\\Usage: ./file_replace pattern replacement file
;

pub fn main() !void {
	var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena_state.deinit();
	const arena = arena_state.allocator();

	const args = try std.process.argsAlloc(arena);

	var optPattern: ?[]const u8 = null;
	var optReplacement: ?[]const u8 = null;
	var optFilePath: ?[]const u8 = null;

	{
		var i: usize = 1;
		while(i < args.len) : (i += 1) {
			const arg = args[i];
			if(std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
				try std.fs.File.stdout().writeAll(usage);
				return std.process.cleanExit();
			} else if(i == 1) {
				optPattern = args[i];
			} else if(i == 2) {
				optReplacement = args[i];
			} else if(i == 3) {
				optFilePath = args[i];
			} else {
				fatal("superfluous arg: '{s}'", .{arg});
			}
		}
	}

	const pattern = optPattern orelse fatal("missing pattern", .{});
	if(pattern.len == 0) {
		fatal("pattern is empty (not allowed)", .{});
	}
	const replacement = optReplacement orelse fatal("missing replacement", .{});
	const filePath = optFilePath orelse fatal("missing file", .{});

	const outputFilePathSuffix = ".tmp";
	const tmpOutputFilePathLength = filePath.len + outputFilePathSuffix.len;
	var outputFilePath = arena.alloc(u8, tmpOutputFilePathLength) catch fatal("path allocation failed", .{});
	defer arena.free(outputFilePath);
	std.mem.copyForwards(u8, outputFilePath[0..filePath.len], filePath);
	std.mem.copyForwards(u8, outputFilePath[filePath.len..], outputFilePathSuffix);

	{
		var inputFile = std.fs.cwd().openFile(filePath, .{}) catch |err| {
			fatal("unable to open '{s}': {s}", .{filePath, @errorName(err)});
		};
		defer inputFile.close();

		const inputFileStat = inputFile.stat() catch fatal("retrieving file size failed", .{});
		if(inputFileStat.size > 1024*1024*1024) {
			fatal("file too large (must not be larger than 1 GiB)", .{});
		}

		const buffer = std.heap.page_allocator.alloc(u8, inputFileStat.size) catch fatal("file buffer allocation failed", .{});
		defer std.heap.page_allocator.free(buffer);
		const readByteCount = inputFile.readAll(buffer) catch |err| {
			fatal("file reading failed: {s}", .{@errorName(err)});
		};
		if(readByteCount != inputFileStat.size) {
			fatal("file reading failed", .{});
		}

		if(std.fs.cwd().access(outputFilePath, .{.mode = .read_write})) |_| {
			fatal("tmp output file '{s}' does already exist", .{outputFilePath});
		} else |_| {}

		const outputFile = std.fs.cwd().createFile(outputFilePath, .{}) catch |err| {
			fatal("unable to open '{s}' for write: {s}", .{outputFilePath, @errorName(err)});
		};
		defer outputFile.close();

		// NOTE(blackedout): Match the pattern, if complete, write block before pattern, then replacement.
		// Finally write remaining block
		var matchLength: u64 = 0;
		var lastWriteEnd: u64 = 0;
		var index: u64 = 0;
		while(index < inputFileStat.size) : (index += 1) {
			if(buffer[index] == pattern[matchLength]) {
				matchLength += 1;

				if(matchLength >= pattern.len) {
					outputFile.writeAll(buffer[lastWriteEnd..(index + 1 - pattern.len)]) catch |err| {
						fatal("file writing failed: {s}", .{@errorName(err)});
					};
					outputFile.writeAll(replacement) catch |err| {
						fatal("file writing failed: {s}", .{@errorName(err)});
					};
					lastWriteEnd = index + 1;
					matchLength = 0;
				}
			} else {
				matchLength = 0;
			}
		}
		outputFile.writeAll(buffer[lastWriteEnd..inputFileStat.size]) catch |err| {
			fatal("file writing failed: {s}", .{@errorName(err)});
		};
	}

	std.fs.cwd().deleteFile(filePath) catch |err| {
		fatal("deleting input file failed: {s}", .{@errorName(err)});
	};
	std.fs.cwd().rename(outputFilePath, filePath) catch |err| {
		fatal("renaming temporary file failed: {s}", .{@errorName(err)});
	};

	return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
	std.debug.print(format, args);
	std.process.exit(1);
}
