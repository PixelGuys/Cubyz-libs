const std = @import("std");

fn addPackageCSourceFiles(exe: *std.Build.Step.Compile, dep: *std.Build.Dependency, files: []const []const u8, flags: []const []const u8) void {
	for(files) |file| {
		exe.addCSourceFile(.{ .file =  dep.path(file), .flags = flags});
	}
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

pub fn addFreetypeAndHarfbuzz(b: *std.Build, c_lib: *std.Build.Step.Compile, target: anytype, optimize: std.builtin.OptimizeMode, flags: []const []const u8) void {
	const freetype = b.dependency("freetype", .{
		.target = target,
		.optimize = optimize,
	});
	const harfbuzz = b.dependency("harfbuzz", .{
		.target = target,
		.optimize = optimize,
	});

	c_lib.defineCMacro("FT2_BUILD_LIBRARY", "1");
	c_lib.defineCMacro("HAVE_UNISTD_H", "1");
	c_lib.addIncludePath(freetype.path("include"));
	c_lib.installHeadersDirectory(freetype.path("include").getPath(b), "");
	addPackageCSourceFiles(c_lib, freetype, &freetypeSources, flags);
	if (target.result.os.tag == .macos) c_lib.addCSourceFile(.{
		.file = freetype.path("src/base/ftmac.c"),
		.flags = &.{},
	});

	c_lib.addIncludePath(harfbuzz.path("src"));
	c_lib.installHeadersDirectory(harfbuzz.path("src").getPath(b), ""); // TODO: Only include the headers.
	c_lib.defineCMacro("HAVE_FREETYPE", "1");
	c_lib.addCSourceFile(.{.file = harfbuzz.path("src/harfbuzz.cc"), .flags = flags});
	c_lib.linkLibCpp();
}

pub fn build(b: *std.Build) !void {
    // Simply don't deallocate the deallocator, let the
    // system clean it up for us. build.zig is not long-
    // lived anyways. Used for dynamically generating strings
    // for the MacOS target.
    // TODO: make this idiomatic
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    // defer { if(gpa.deinit() == .leak) std.log.info("leak :)"); }

	// Standard target options allows the person running `zig build` to choose
	// what target to build for. Here we do not override the defaults, which
	// means any target is allowed, and the default is native. Other options
	// for restricting supported target set are available.
	const target = b.standardTargetOptions(.{});
	const t = target.result;

	// Standard release options allow the person running `zig build` to select
	// between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
	const optimize = b.standardOptimizeOption(.{});
	const c_lib = b.addStaticLibrary(.{
		.name = "cubyz_deps",
		.target = target,
		.optimize = optimize,
	});
	const c_flags = &[_][]const u8{"-g"};
	c_lib.addIncludePath(.{.path = "include"});
	c_lib.installHeader("include/glad/glad.h", "glad/glad.h");
	c_lib.installHeader("include/GLFW/glfw3.h", "GLFW/glfw3.h");
	c_lib.installHeader("include/KHR/khrplatform.h", "KHR/khrplatform.h");
	c_lib.installHeader("include/stb/stb_image_write.h", "stb/stb_image_write.h");
	c_lib.installHeader("include/stb/stb_image.h", "stb/stb_image.h");
	c_lib.installHeader("include/stb/stb_vorbis.h", "stb/stb_vorbis.h");
	{ // compile glfw from source:
		if(t.os.tag == .windows) {
			c_lib.addCSourceFiles(.{.files = &[_][]const u8 {
				"lib/glfw/src/win32_init.c", "lib/glfw/src/win32_joystick.c", "lib/glfw/src/win32_monitor.c", "lib/glfw/src/win32_time.c", "lib/glfw/src/win32_thread.c", "lib/glfw/src/win32_window.c", "lib/glfw/src/wgl_context.c", "lib/glfw/src/egl_context.c", "lib/glfw/src/osmesa_context.c", "lib/glfw/src/context.c", "lib/glfw/src/init.c", "lib/glfw/src/input.c", "lib/glfw/src/monitor.c", "lib/glfw/src/vulkan.c", "lib/glfw/src/window.c"
			}, .flags = c_flags ++ &[_][]const u8{"-std=c99", "-D_GLFW_WIN32"}});
		} else if(t.os.tag == .linux) {
			// TODO: if(isWayland) {
			//	c_lib.addCSourceFiles(&[_][]const u8 {
			//		"lib/glfw/src/linux_joystick.c", "lib/glfw/src/wl_init.c", "lib/glfw/src/wl_monitor.c", "lib/glfw/src/wl_window.c", "lib/glfw/src/posix_time.c", "lib/glfw/src/posix_thread.c", "lib/glfw/src/xkb_unicode.c", "lib/glfw/src/egl_context.c", "lib/glfw/src/osmesa_context.c", "lib/glfw/src/context.c", "lib/glfw/src/init.c", "lib/glfw/src/input.c", "lib/glfw/src/monitor.c", "lib/glfw/src/vulkan.c", "lib/glfw/src/window.c"
			//	}, &[_][]const u8{"-g",});
			//} else {
				c_lib.addCSourceFiles(.{.files = &[_][]const u8 {
					"lib/glfw/src/linux_joystick.c", "lib/glfw/src/x11_init.c", "lib/glfw/src/x11_monitor.c", "lib/glfw/src/x11_window.c", "lib/glfw/src/xkb_unicode.c", "lib/glfw/src/posix_time.c", "lib/glfw/src/posix_thread.c", "lib/glfw/src/glx_context.c", "lib/glfw/src/egl_context.c", "lib/glfw/src/osmesa_context.c", "lib/glfw/src/context.c", "lib/glfw/src/init.c", "lib/glfw/src/input.c", "lib/glfw/src/monitor.c", "lib/glfw/src/vulkan.c", "lib/glfw/src/window.c"
				}, .flags = c_flags ++ &[_][]const u8{"-std=c99", "-D_GLFW_X11"}});
			//}
        } else if(t.os.tag == .macos) {
            const mac_posix_time = b.option(bool, "mac-posix_time", "Build posix_time.c into Mac GLFW") orelse false;
            const mac_egl = b.option(bool, "mac-egl", "Build EGL into Mac GLFW") orelse false;
            const mac_osmesa = b.option(bool, "mac-osmesa", "Build OSMESA into Mac GLFW") orelse false;
            const mac_x11 = b.option(bool, "mac-x11", "Build X11 into Mac GLFW") orelse true;
            const mac_cocoa = b.option(bool, "mac-cocoa", "Build Cocoa into Mac GLFW") orelse false;
            const mac_nsgl = b.option(bool, "mac-nsgl", "Build NSGL into Mac GLFW") orelse false;
            // TODO: Do this properly.
            const mac_window_system = b.option([]const u8, "mac-window-system", "Window system flag to pass to Mac GLFW: -D_GLFW_X11, -D_GLFW_COCOA, or -D_GLFW_OSMESA") orelse "-D_GLFW_X11";
            // Building for Zink requires EGL and COCOA, while LLVMpipe needs X11.
            // These conflict with each other but I'll let the user figure it
            // out.
            var files = std.ArrayList([]const u8).init(alloc);
            // GLFW
            try files.appendSlice(&[_][]const u8 { "lib/glfw/src/context.c", "lib/glfw/src/init.c", "lib/glfw/src/input.c", "lib/glfw/src/monitor.c", "lib/glfw/src/vulkan.c", "lib/glfw/src/window.c", "lib/glfw/src/posix_thread.c" });
            // POSIX
            if(mac_posix_time) try files.appendSlice(&[_][]const u8 { "lib/glfw/src/posix_time.c" });
            // EGL
            if(mac_egl) try files.appendSlice(&[_][]const u8 { "lib/glfw/src/egl_context.c" });
            // OSMesa
            if(mac_osmesa) try files.appendSlice(&[_][]const u8 { "lib/glfw/src/null_joystick.c", "lib/glfw/src/osmesa_context.c" });
            // X11
            if(mac_x11) try files.appendSlice(&[_][]const u8 { "lib/glfw/src/x11_init.c", "lib/glfw/src/x11_monitor.c", "lib/glfw/src/x11_window.c", "lib/glfw/src/xkb_unicode.c", "lib/glfw/src/glx_context.c" });
            // Cocoa
            if(mac_cocoa) try files.appendSlice(&[_][]const u8 { "lib/glfw/src/cocoa_time.c", "lib/glfw/src/cocoa_init.m", "lib/glfw/src/cocoa_joystick.m", "lib/glfw/src/cocoa_monitor.m", "lib/glfw/src/cocoa_window.m" });
            // NSGL
            if(mac_nsgl) try files.appendSlice(&[_][]const u8 { "lib/glfw/src/nsgl_context.m" });
            c_lib.addCSourceFiles(
                .{.files = files.items,
                .flags = c_flags ++ &[_][]const u8{
                "-std=c99",
                mac_window_system
            }});
            c_lib.addIncludePath(.{.path="/opt/X11/include"});
		} else {
			std.log.err("Unsupported target: {}\n", .{ t.os.tag });
		}
	}
	{ // compile portaudio from source:
		const portaudio = b.dependency("portaudio", .{
			.target = target,
			.optimize = optimize,
		});
		c_lib.addIncludePath(portaudio.path("include"));
		c_lib.installHeadersDirectory(portaudio.path("include").getPath(b), "");
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
		}, c_flags);
		if(t.os.tag == .windows) {
			// windows:
			addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/os/win/pa_win_coinitialize.c", "src/os/win/pa_win_hostapis.c", "src/os/win/pa_win_util.c", "src/os/win/pa_win_waveformat.c", "src/os/win/pa_win_wdmks_utils.c", "src/os/win/pa_x86_plain_converters.c", }, c_flags ++ &[_][]const u8{"-DPA_USE_WASAPI"});
			c_lib.addIncludePath(portaudio.path("src/os/win"));
			// WASAPI:
			addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/hostapi/wasapi/pa_win_wasapi.c"}, c_flags);
		} else if(t.os.tag == .linux) {
			// unix:
			addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/os/unix/pa_unix_hostapis.c", "src/os/unix/pa_unix_util.c"}, c_flags ++ &[_][]const u8{"-DPA_USE_ALSA"});
			c_lib.addIncludePath(portaudio.path("src/os/unix"));
			// ALSA:
			addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/hostapi/alsa/pa_linux_alsa.c"}, c_flags);
        } else if(t.os.tag == .macos) {
			addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/os/unix/pa_unix_hostapis.c", "src/os/unix/pa_unix_util.c"}, c_flags ++ &[_][]const u8{"-DPA_USE_COREAUDIO"});
			// coreaudio:
			addPackageCSourceFiles(c_lib, portaudio, &[_][]const u8 {"src/hostapi/coreaudio/pa_mac_core_utilities.c", "src/hostapi/coreaudio/pa_mac_core.c", "src/hostapi/coreaudio/pa_mac_core_blocking.c", }, c_flags ++ &[_][]const u8{"-DPA_USE_COREAUDIO"});
		} else {
			std.log.err("Unsupported target: {}\n", .{ t.os.tag });
		}
	}
	c_lib.addCSourceFiles(.{.files = &[_][]const u8{"lib/glad.c", "lib/stb_image.c", "lib/stb_image_write.c", "lib/stb_vorbis.c"}, .flags = c_flags});

	addFreetypeAndHarfbuzz(b, c_lib, target, optimize, c_flags);

	b.installArtifact(c_lib);
}
