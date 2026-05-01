// NOTE(blackedout): Modified from https://ziglang.org/learn/build-system/#project-tools (2025-10-29)
// Both the input and the output file will be present in memory simultaneously and entirely at some point,
// so calling this for extremely large files might be a bad idea.

const std = @import("std");
const panic = std.debug.panic;

const usage =
	\\Usage: ./file_replace pattern replacement file
;

var threadedIo: std.Io.Threaded = undefined;
pub var io: std.Io = threadedIo.io();

pub fn main(init: std.process.Init.Minimal) !void {
	var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena_state.deinit();
	const arena = arena_state.allocator();

	const args = try init.args.toSlice(arena);
	if (args.len != 4) {
		try std.Io.File.stdout().writeStreamingAll(io, usage);
		return std.process.cleanExit(io);
	}

	const pattern = args[1];
	if (pattern.len == 0) {
		fatal("pattern is empty (not allowed)", .{});
	}
	const replacement = args[2];
	const filePath = args[3];

	const outputFilePath = try std.mem.concat(arena, u8, &.{filePath, ".tmp"});
	defer arena.free(outputFilePath);

	if (std.Io.Dir.cwd().access(io, outputFilePath, .{.read = true, .write = true})) |_| {
		fatal("tmp output file '{s}' does already exist", .{outputFilePath});
	} else |_| {}

	const fileContents = std.Io.Dir.cwd().readFileAlloc(io, filePath, std.heap.page_allocator, .limited(std.math.maxInt(usize))) catch |err| switch (err) {
		else => fatal("file reading failed: {s}", .{@errorName(err)}),
	};
	defer std.heap.page_allocator.free(fileContents);

	const replacedSize = std.mem.replacementSize(u8, fileContents, pattern, replacement);
	const replacementBuffer = try std.heap.page_allocator.alloc(u8, replacedSize);
	defer std.heap.page_allocator.free(replacementBuffer);
	_ = std.mem.replace(u8, fileContents, pattern, replacement, replacementBuffer);

	std.Io.Dir.cwd().writeFile(io, .{.sub_path = outputFilePath, .data = replacementBuffer}) catch |err| {
		fatal("file writing failed: {s}", .{@errorName(err)});
	};
	std.Io.Dir.cwd().rename(outputFilePath, std.Io.Dir.cwd(), filePath, io) catch |err| {
		fatal("renaming temporary file failed: {s}", .{@errorName(err)});
	};

	return std.process.cleanExit(io);
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
	panic(format, args);
}
