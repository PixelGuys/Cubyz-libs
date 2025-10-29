// NOTE(blackedout): Modified from https://ziglang.org/learn/build-system/#project-tools (2025-10-29)

const std = @import("std");

const usage =
	\\Usage: ./file_replace pattern replacement file
;

pub fn main() !void {
	var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena_state.deinit();
	const arena = arena_state.allocator();

	const args = try std.process.argsAlloc(arena);
	if(args.len != 4) {
		try std.fs.File.stdout().writeAll(usage);
		return std.process.cleanExit();
	}

	const pattern = args[1];
	if(pattern.len == 0) {
		fatal("pattern is empty (not allowed)", .{});
	}
	const replacement = args[2];
	const filePath = args[3];

	const outputFilePath = try std.mem.concat(arena, u8, &.{filePath, ".tmp"});
	defer arena.free(outputFilePath);

	if(std.fs.cwd().access(outputFilePath, .{.mode = .read_write})) |_| {
		fatal("tmp output file '{s}' does already exist", .{outputFilePath});
	} else |_| {}

	const fileContents = std.fs.cwd().readFileAlloc(std.heap.page_allocator, filePath, std.math.maxInt(usize)) catch |err| switch(err) {
		else => fatal("file reading failed: {s}", .{@errorName(err)}),
	};
	defer std.heap.page_allocator.free(fileContents);

	const replacedSize = std.mem.replacementSize(u8, fileContents, pattern, replacement);
	const replacementBuffer = try std.heap.page_allocator.alloc(u8, replacedSize);
	defer std.heap.page_allocator.free(replacementBuffer);
	_ = std.mem.replace(u8, fileContents, pattern, replacement, replacementBuffer);

	std.fs.cwd().writeFile(.{.sub_path = outputFilePath, .data = replacementBuffer}) catch |err| {
		fatal("file writing failed: {s}", .{@errorName(err)});
	};
	std.fs.cwd().rename(outputFilePath, filePath) catch |err| {
		fatal("renaming temporary file failed: {s}", .{@errorName(err)});
	};

	return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
	std.debug.panic(format, args);
}
