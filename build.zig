const std = @import("std");

const targets: []const std.Target.Query = &.{
	// NB: some of these targets don't build yet in Cubyz, but are
	// included for completion's sake
	.{ .cpu_arch = .aarch64, .os_tag = .macos },
	.{ .cpu_arch = .aarch64, .os_tag = .linux },
	.{ .cpu_arch = .aarch64, .os_tag = .windows },
	.{ .cpu_arch = .x86_64, .os_tag = .macos },
	.{ .cpu_arch = .x86_64, .os_tag = .linux },
	.{ .cpu_arch = .x86_64, .os_tag = .windows },
};

fn addPackageCSourceFiles(exe: *std.Build.Step.Compile, dep: *std.Build.Dependency, files: []const []const u8, flags: []const []const u8) void {
	exe.addCSourceFiles(.{
		.root = dep.path(""),
		.files = files,
		.flags = flags,
	});
}

const freetypeSources = [_][]const u8{
	"src/autofit/autofit.c",
	"src/base/ftbase.c",
	"src/base/ftsystem.c",
	"src/base/ftdebug.c",
	"src/base/ftbbox.c",
	"src/base/ftbdf.c",
	"src/base/ftbitmap.c",
	"src/base/ftcid.c",
	"src/base/ftfstype.c",
	"src/base/ftgasp.c",
	"src/base/ftglyph.c",
	"src/base/ftgxval.c",
	"src/base/ftinit.c",
	"src/base/ftmm.c",
	"src/base/ftotval.c",
	"src/base/ftpatent.c",
	"src/base/ftpfr.c",
	"src/base/ftstroke.c",
	"src/base/ftsynth.c",
	"src/base/fttype1.c",
	"src/base/ftwinfnt.c",
	"src/bdf/bdf.c",
	"src/bzip2/ftbzip2.c",
	"src/cache/ftcache.c",
	"src/cff/cff.c",
	"src/cid/type1cid.c",
	"src/gzip/ftgzip.c",
	"src/lzw/ftlzw.c",
	"src/pcf/pcf.c",
	"src/pfr/pfr.c",
	"src/psaux/psaux.c",
	"src/pshinter/pshinter.c",
	"src/psnames/psnames.c",
	"src/raster/raster.c",
	"src/sdf/sdf.c",
	"src/sfnt/sfnt.c",
	"src/smooth/smooth.c",
	"src/svg/svg.c",
	"src/truetype/truetype.c",
	"src/type1/type1.c",
	"src/type42/type42.c",
	"src/winfonts/winfnt.c",
};

// Inlines are necessaryb to preserve comptime status of flags.
pub inline fn addPortAudio(b: *std.Build, c_lib: *std.Build.Step.Compile, target:std.Build.ResolvedTarget, flags: []const []const u8) void {
	// compile portaudio from source:
	const portaudio = b.dependency("portaudio", .{});
	c_lib.addIncludePath(portaudio.path("include"));
	c_lib.installHeadersDirectory(portaudio.path("include"), "", .{});
	c_lib.addIncludePath(portaudio.path("src/common"));
	addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {
		"src/common/pa_allocation.c",
		"src/common/pa_converters.c",
		"src/common/pa_cpuload.c",
		"src/common/pa_debugprint.c",
		"src/common/pa_dither.c",
		"src/common/pa_front.c",
		"src/common/pa_process.c",
		"src/common/pa_ringbuffer.c",
		"src/common/pa_stream.c",
		"src/common/pa_trace.c",
	}, flags);
	if(target.result.os.tag == .windows) {
		// windows:
		addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/os/win/pa_win_coinitialize.c", "src/os/win/pa_win_hostapis.c", "src/os/win/pa_win_util.c", "src/os/win/pa_win_waveformat.c", "src/os/win/pa_win_wdmks_utils.c", "src/os/win/pa_x86_plain_converters.c", }, flags ++ &[_][]const u8{"-DPA_USE_WASAPI"});
		c_lib.addIncludePath(portaudio.path("src/os/win"));
		// WASAPI:
		addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/hostapi/wasapi/pa_win_wasapi.c"}, flags);
	} else if(target.result.os.tag == .linux) {
		// unix:
		addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/os/unix/pa_unix_hostapis.c", "src/os/unix/pa_unix_util.c"}, flags ++ &[_][]const u8{"-DPA_USE_ALSA"});
		c_lib.addIncludePath(portaudio.path("src/os/unix"));
		// ALSA:
		addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/hostapi/alsa/pa_linux_alsa.c"}, flags);
	} else if(target.result.os.tag == .macos) {
		addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/os/unix/pa_unix_hostapis.c", "src/os/unix/pa_unix_util.c"}, flags ++ &[_][]const u8{"-DPA_USE_COREAUDIO"});
		// coreaudio:
		addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/hostapi/coreaudio/pa_mac_core_utilities.c", "src/hostapi/coreaudio/pa_mac_core.c", "src/hostapi/coreaudio/pa_mac_core_blocking.c", }, flags ++ &[_][]const u8{"-DPA_USE_COREAUDIO"});
	} else {
		std.log.err("Unsupported target: {}\n", .{ target.result.os.tag });
	}
}

pub fn addFreetypeAndHarfbuzz(b: *std.Build, c_lib: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, flags: []const []const u8) void {
	const freetype = b.dependency("freetype", .{});
	const harfbuzz = b.dependency("harfbuzz", .{});

	c_lib.defineCMacro("FT2_BUILD_LIBRARY", "1");
	c_lib.defineCMacro("HAVE_UNISTD_H", "1");
	c_lib.addIncludePath(freetype.path("include"));
	c_lib.installHeadersDirectory(freetype.path("include"), "", .{});
	addPackageCSourceFiles(c_lib, freetype, &freetypeSources, flags);
	if (target.result.os.tag == .macos) c_lib.addCSourceFile(.{
		.file = freetype.path("src/base/ftmac.c"),
		.flags = &.{},
	});

	c_lib.addIncludePath(harfbuzz.path("src"));
	c_lib.installHeadersDirectory(harfbuzz.path("src"), "", .{});
	c_lib.defineCMacro("HAVE_FREETYPE", "1");
	c_lib.addCSourceFile(.{.file = harfbuzz.path("src/harfbuzz.cc"), .flags = flags});
	c_lib.linkLibCpp();
}

pub inline fn addGLFWSources(b: *std.Build, c_lib: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, flags: []const []const u8) void {
	const glfw = b.dependency("glfw", .{});
	const root = glfw.path("src");
	const os = target.result.os.tag;

	const WinSys = enum {win32, x11, cocoa};

	// TODO: Wayland
	// TODO: Cocoa
	const ws: WinSys = switch(os) {
		.windows => .win32,
		.linux => .x11,
		.macos => .x11,
		// There are a surprising number of platforms zig supports.
		// File a bug report if Cubyz doesn't work on yours.
		else => blk: {
			std.log.warn("Operating system ({}) is untested.", .{os});
			break :blk .x11;
		}
	};
	const ws_flag = switch(ws) {
		.win32 => "-D_GLFW_WIN32",
		.x11 => "-D_GLFW_X11",
		.cocoa => "-D_GLFW_COCOA",
	};
	var all_flags = std.ArrayList([]const u8).init(b.allocator);
	all_flags.appendSlice(flags) catch unreachable;
	all_flags.append(ws_flag) catch unreachable;
	if(os == .linux) {
		all_flags.append("-D_GNU_SOURCE") catch unreachable;
	}

	c_lib.addIncludePath(.{.path = glfw.path("include").getPath(b)});
	c_lib.installHeader(glfw.path("include/GLFW/glfw3.h"), "GLFW/glfw3.h");
	const fileses : [3][]const[]const u8 = .{
		&.{"context.c", "init.c", "input.c", "monitor.c", "platform.c", "vulkan.c", "window.c", "egl_context.c", "osmesa_context.c", "null_init.c", "null_monitor.c", "null_window.c", "null_joystick.c"},
		switch(os) {
			.windows => &.{"win32_module.c", "win32_time.c", "win32_thread.c" },
			.linux => &.{"posix_module.c", "posix_time.c", "posix_thread.c", "linux_joystick.c"},
			.macos => &.{"cocoa_time.c", "posix_module.c", "posix_thread.c"},
			else => &.{"posix_module.c", "posix_time.c", "posix_thread.c", "linux_joystick.c"},
		},
		switch(ws) {
			.win32 => &.{"win32_init.c", "win32_joystick.c", "win32_monitor.c", "win32_window.c", "wgl_context.c"},
			.x11 => &.{"x11_init.c", "x11_monitor.c", "x11_window.c", "xkb_unicode.c", "glx_context.c", "posix_poll.c"},
			.cocoa => &.{"cocoa_platform.h", "cocoa_joystick.h", "cocoa_init.m", "cocoa_joystick.m", "cocoa_monitor.m", "cocoa_window.m", "nsgl_context.m"},
		}
	};

	for(fileses) |files| {
		c_lib.addCSourceFiles(.{
			.root = root,
			.files = files,
			.flags = all_flags.items,
		});
	}
}

pub inline fn makeCubyzLibs(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, flags: []const []const u8) *std.Build.Step.Compile {
	const c_lib = b.addStaticLibrary(.{
		.name = name,
		.target = target,
		.optimize = optimize,
	});

	c_lib.addAfterIncludePath(.{.path = "include"});
	c_lib.installHeader(.{.path = "include/glad/glad.h"}, "glad/glad.h");
	c_lib.installHeader(.{.path = "include/KHR/khrplatform.h"}, "KHR/khrplatform.h");
	c_lib.installHeader(.{.path = "include/stb/stb_image_write.h"}, "stb/stb_image_write.h");
	c_lib.installHeader(.{.path = "include/stb/stb_image.h"}, "stb/stb_image.h");
	c_lib.installHeader(.{.path = "include/stb/stb_vorbis.h"}, "stb/stb_vorbis.h");
	addPortAudio(b, c_lib, target, flags);
	addFreetypeAndHarfbuzz(b, c_lib, target, flags);
	addGLFWSources(b, c_lib, target, flags);
	c_lib.addCSourceFile(.{.file = .{.path = "lib/glad.c"}, .flags = flags ++ &[_][]const u8 {"-D_MAC_X11"}});
	c_lib.addCSourceFiles(.{.files = &[_][]const u8{"lib/stb_image.c", "lib/stb_image_write.c", "lib/stb_vorbis.c"}, .flags = flags});

	return c_lib;
}


pub fn build(b: *std.Build) !void {
	// Standard target options allows the person running `zig build` to choose
	// what target to build for. Here we do not override the defaults, which
	// means any target is allowed, and the default is native. Other options
	// for restricting supported target set are available.
	const preferredTarget = b.standardTargetOptions(.{});

	// Standard release options allow the person running `zig build` to select
	// between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
	const preferredOptimize = b.standardOptimizeOption(.{});
	const c_flags = &[_][]const u8{"-g"};

	const releaseStep = b.step("release", "Build and package all targets for distribution");
	const nativeStep = b.step("native", "Build only native target for debugging or local builds");

	for (targets) |target| {
		const t = b.resolveTargetQuery(target);
		const name = t.result.linuxTriple(b.allocator) catch unreachable;
		const subStep = b.step(name, b.fmt("Build only {s}", .{name}));
		const deps = b.fmt("cubyz_deps_{s}", .{name});
		const c_lib = makeCubyzLibs(b, deps, t, .ReleaseSmall, c_flags);
		const install = b.addInstallArtifact(c_lib, .{});

		subStep.dependOn(&install.step);
		releaseStep.dependOn(subStep);
	}

	{
		const name = preferredTarget.result.linuxTriple(b.allocator) catch unreachable;
		const c_lib = makeCubyzLibs(b, b.fmt("cubyz_deps_{s}", .{name}), preferredTarget, preferredOptimize, c_flags);
		const install = b.addInstallArtifact(c_lib, .{});

		nativeStep.dependOn(&install.step);
	}

	// Alias the default `zig build` to only build native target.
	// Run `zig build release` to build all targets.
	b.getInstallStep().dependOn(nativeStep);
}
