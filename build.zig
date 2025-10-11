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

pub fn addFreetypeAndHarfbuzz(b: *std.Build, c_lib: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, flags: []const []const u8) void {
	const freetype = b.dependency("freetype", .{});
	const harfbuzz = b.dependency("harfbuzz", .{});

	c_lib.root_module.addCMacro("FT2_BUILD_LIBRARY", "1");
	c_lib.root_module.addCMacro("HAVE_UNISTD_H", "1");
	c_lib.addIncludePath(freetype.path("include"));
	c_lib.installHeadersDirectory(freetype.path("include"), "", .{});
	addPackageCSourceFiles(c_lib, freetype, &freetypeSources, flags);
	if (target.result.os.tag == .macos) c_lib.addCSourceFile(.{
		.file = freetype.path("src/base/ftmac.c"),
		.flags = &.{},
	});

	c_lib.addIncludePath(harfbuzz.path("src"));
	c_lib.installHeadersDirectory(harfbuzz.path("src"), "", .{});
	c_lib.root_module.addCMacro("HAVE_FREETYPE", "1");
	c_lib.addCSourceFile(.{.file = harfbuzz.path("src/harfbuzz.cc"), .flags = flags});
	c_lib.linkLibCpp();
}

pub inline fn addGLFWSources(b: *std.Build, c_lib: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, flags: []const []const u8) void {
	const glfw = b.dependency("glfw", .{});
	const root = glfw.path("src");
	const os = target.result.os.tag;

	const WinSys = enum {win32, x11, x11_wl, cocoa};

	// TODO: Cocoa
	const ws: WinSys = switch(os) {
		.windows => .win32,
		.linux => .x11_wl,
		.macos => .x11,
		// There are a surprising number of platforms zig supports.
		// File a bug report if Cubyz doesn't work on yours.
		else => blk: {
			std.log.warn("Operating system ({}) is untested.", .{os});
			break :blk .x11_wl;
		},
	};
	const ws_flags: []const []const u8 = switch (ws) {
		.win32 => &.{"-D_GLFW_WIN32"},
		.x11 => &.{"-D_GLFW_X11"},
		.x11_wl => &.{"-D_GLFW_X11", "-D_GLFW_WAYLAND"},
		.cocoa => &.{"-D_GLFW_COCOA"},
	};
	var all_flags = std.ArrayList([]const u8).init(b.allocator);
	all_flags.appendSlice(flags) catch unreachable;
	all_flags.appendSlice(ws_flags) catch unreachable;
	if(os == .linux) {
		all_flags.append("-D_GNU_SOURCE") catch unreachable;
	}

	c_lib.addIncludePath(glfw.path("include"));
	c_lib.installHeader(glfw.path("include/GLFW/glfw3.h"), "GLFW/glfw3.h");
	const fileses : [3][]const[]const u8 = .{
		&.{"context.c", "init.c", "input.c", "monitor.c", "platform.c", "vulkan.c", "window.c", "egl_context.c", "osmesa_context.c", "null_init.c", "null_monitor.c", "null_window.c", "null_joystick.c"},
		switch(os) {
			.windows => &.{"win32_module.c", "win32_time.c", "win32_thread.c"},
			.linux => &.{"posix_module.c", "posix_time.c", "posix_thread.c", "linux_joystick.c"},
			.macos => &.{"cocoa_time.c", "posix_module.c", "posix_thread.c"},
			else => &.{"posix_module.c", "posix_time.c", "posix_thread.c", "linux_joystick.c"},
		},
		switch(ws) {
			.win32 => &.{"win32_init.c", "win32_joystick.c", "win32_monitor.c", "win32_window.c", "wgl_context.c"},
			.x11 => &.{"x11_init.c", "x11_monitor.c", "x11_window.c", "xkb_unicode.c", "glx_context.c", "posix_poll.c"},
			.x11_wl => &.{"x11_init.c", "x11_monitor.c", "x11_window.c", "xkb_unicode.c", "glx_context.c", "posix_poll.c", "wl_init.c", "wl_monitor.c", "wl_window.c"},
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

	if(ws == .x11_wl) {
		const wayland_version: std.SemanticVersion = .{
			.major = 1,
			.minor = 24,
			.patch = 0,
		};

		const libwayland = b.dependency("libwayland", .{});
		c_lib.addIncludePath(libwayland.path("src"));

		const wayland_version_header = b.addConfigHeader(.{
			.style = .{.cmake = libwayland.path("src/wayland-version.h.in")},
		}, .{
			.WAYLAND_VERSION_MAJOR = @as(i64, @intCast(wayland_version.major)),
			.WAYLAND_VERSION_MINOR = @as(i64, @intCast(wayland_version.minor)),
			.WAYLAND_VERSION_MICRO = @as(i64, @intCast(wayland_version.patch)),
			.WAYLAND_VERSION = b.fmt("{}", .{wayland_version}),
		});

		c_lib.addConfigHeader(wayland_version_header);

		const wl_scanner = b.addExecutable(.{
			.name = "wayland-scanner",
			.root_module = b.createModule(.{
				.link_libc = true,
				// This is intentionally our host target, since we only run wayland-scanner natively
				// as part of this build script. It isn't part of our output.
				.target = b.graph.host,
			}),
		});
		wl_scanner.addCSourceFiles(.{
			.root = libwayland.path("src"),
			.files = &.{
				"scanner.c",
				"wayland-util.c",
			},
		});
		wl_scanner.addConfigHeader(wayland_version_header);
		wl_scanner.addIncludePath(libwayland.path(""));
		wl_scanner.addIncludePath(libwayland.path("src"));

		if(b.lazyDependency("libexpat", .{.target = b.graph.host})) |expat| {
			wl_scanner.linkLibrary(expat.artifact("expat"));
		}

		const wl_protocols = [_]GenerateWaylandProtocolsStep.WaylandProtocolSpec{
			.{.input_xml = glfw.path("deps/wayland/wayland.xml"), .output_basename = "wayland"},
			.{.input_xml = glfw.path("deps/wayland/viewporter.xml"), .output_basename = "viewporter"},
			.{.input_xml = glfw.path("deps/wayland/xdg-shell.xml"), .output_basename = "xdg-shell"},
			.{.input_xml = glfw.path("deps/wayland/idle-inhibit-unstable-v1.xml"), .output_basename = "idle-inhibit-unstable-v1"},
			.{.input_xml = glfw.path("deps/wayland/pointer-constraints-unstable-v1.xml"), .output_basename = "pointer-constraints-unstable-v1"},
			.{.input_xml = glfw.path("deps/wayland/relative-pointer-unstable-v1.xml"), .output_basename = "relative-pointer-unstable-v1"},
			.{.input_xml = glfw.path("deps/wayland/fractional-scale-v1.xml"), .output_basename = "fractional-scale-v1"},
			.{.input_xml = glfw.path("deps/wayland/xdg-activation-v1.xml"), .output_basename = "xdg-activation-v1"},
			.{.input_xml = glfw.path("deps/wayland/xdg-decoration-unstable-v1.xml"), .output_basename = "xdg-decoration-unstable-v1"},
		};
		const wl_step = GenerateWaylandProtocolsStep.init(b, &wl_protocols, wl_scanner);
		c_lib.step.dependOn(&wl_step.step);

		c_lib.addIncludePath(wl_step.headersPath());
	}
}

const GenerateWaylandProtocolsStep = struct {
	const WaylandProtocolSpec = struct {
		input_xml: std.Build.LazyPath,
		output_basename: []const u8,
	};

	step: std.Build.Step,
	headers_output: std.Build.GeneratedFile,
	inputs: []const WaylandProtocolSpec,
	wl_scanner: *std.Build.Step.Compile,

	fn init(b: *std.Build, inputs: []const WaylandProtocolSpec, wl_scanner: *std.Build.Step.Compile) *GenerateWaylandProtocolsStep {
		const self = b.allocator.create(GenerateWaylandProtocolsStep) catch unreachable;

		const inputs_dupe = b.allocator.dupe(WaylandProtocolSpec, inputs) catch unreachable;

		self.* = .{
			.step = std.Build.Step.init(.{
				.name = "generate-wayland-protocols",
				.makeFn = &makeFunction,
				.owner = b,
				.id = .custom,
			}),
			.headers_output = .{.step = &self.step},
			.inputs = inputs_dupe,
			.wl_scanner = wl_scanner,
		};

		for(inputs) |input| {
			input.input_xml.addStepDependencies(&self.step);
		}

		wl_scanner.getEmittedBin().addStepDependencies(&self.step);

		return self;
	}

	fn headersPath(self: *const GenerateWaylandProtocolsStep) std.Build.LazyPath {
		return .{.generated = .{.file = &self.headers_output}};
	}

	fn makeFunction(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
		const self: *GenerateWaylandProtocolsStep = @fieldParentPtr("step", step);
		const b = step.owner;

		var man = b.graph.cache.obtain();
		defer man.deinit();

		// Random bytes. Update when there's a breaking change to this code.
		man.hash.add(@as(u32, 0x68b6d51a));

		for(self.inputs) |protospec| {
			const path = try protospec.input_xml.getPath3(b, step).toString(b.allocator);
			_ = try man.addFile(path, null);
		}

		if(try step.cacheHit(&man)) {
			// cache hit
			const final_hash = man.final();
			self.headers_output.path = b.cache_root.join(b.allocator, &.{"o", &final_hash}) catch unreachable;
			step.result_cached = true;
			return;
		}

		const final_hash = man.final();
		const headers_path = b.cache_root.join(b.allocator, &.{"o", &final_hash}) catch unreachable;
		self.headers_output.path = headers_path;

		try std.fs.cwd().makePath(headers_path);

		for(self.inputs) |protospec| {
			const input_xml_path = try protospec.input_xml.getPath3(b, step).toString(b.allocator);
			const wl_scanner_path = try self.wl_scanner.getEmittedBin().getPath3(b, step).toString(b.allocator);

			var hdr_child = std.process.Child.init(&.{
				wl_scanner_path,
				"client-header",
				input_xml_path,
				b.fmt("{s}/{s}-client-protocol.h", .{headers_path, protospec.output_basename}),
			}, b.allocator);
			if(!std.meta.eql(try hdr_child.spawnAndWait(), .{.Exited = 0})) {
				return error.WaylandScannerFailed;
			}

			var src_child = std.process.Child.init(&.{
				wl_scanner_path,
				"private-code",
				input_xml_path,
				// One might be wondering why we're putting these generated source files that are
				// clearly meant to be built as separate compilation units into the include
				// directory.
				// The reason is that GLFW actually #includes them in wl_init.c instead of compiling
				// them separately. Strange, right?
				b.fmt("{s}/{s}-client-protocol-code.h", .{headers_path, protospec.output_basename}),
			}, b.allocator);
			if(!std.meta.eql(try src_child.spawnAndWait(), .{.Exited = 0})) {
				return error.WaylandScannerFailed;
			}
		}

		try step.writeManifest(&man);
	}
};

pub inline fn makeCubyzLibs(b: *std.Build, step: *std.Build.Step, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, flags: []const []const u8) *std.Build.Step.Compile {
	const c_lib = b.addStaticLibrary(.{
		.name = name,
		.target = target,
		.optimize = optimize,
	});

	c_lib.addAfterIncludePath(b.path("include"));
	c_lib.installHeader(b.path("include/glad/gl.h"), "glad/gl.h");
	c_lib.installHeader(b.path("include/glad/vulkan.h"), "glad/vulkan.h");
	c_lib.installHeader(b.path("include/KHR/khrplatform.h"), "KHR/khrplatform.h");
	c_lib.installHeader(b.path("include/vk_platform.h"), "vk_platform.h");
	c_lib.installHeader(b.path("include/stb/stb_image_write.h"), "stb/stb_image_write.h");
	c_lib.installHeader(b.path("include/stb/stb_image.h"), "stb/stb_image.h");
	c_lib.installHeader(b.path("include/stb/stb_vorbis.h"), "stb/stb_vorbis.h");
	c_lib.installHeader(b.path("include/miniaudio.h"), "miniaudio.h");
	addFreetypeAndHarfbuzz(b, c_lib, target, flags);
	addGLFWSources(b, c_lib, target, flags);
	c_lib.addCSourceFile(.{.file = b.path("lib/gl.c"), .flags = flags ++ &[_][]const u8 {"-D_MAC_X11"}});
	c_lib.addCSourceFile(.{.file = b.path("lib/vulkan.c"), .flags = flags ++ &[_][]const u8 {"-D_MAC_X11"}});
	c_lib.addCSourceFiles(.{.files = &[_][]const u8{"lib/stb_image.c", "lib/stb_image_write.c", "lib/stb_vorbis.c", "lib/miniaudio.c"}, .flags = flags});
	const glslang = b.dependency("glslang", .{
		.target = target,
		.optimize = optimize,
		.@"enable-opt" = true,
	});
	const options = std.Build.Step.InstallArtifact.Options {
		.dest_dir = .{.override = .{.custom = b.fmt("lib/{s}", .{name})}},
	};
	step.dependOn(&b.addInstallArtifact(glslang.artifact("glslang"), options).step);
	step.dependOn(&b.addInstallArtifact(glslang.artifact("MachineIndependent"), options).step);
	step.dependOn(&b.addInstallArtifact(glslang.artifact("GenericCodeGen"), options).step);
	step.dependOn(&b.addInstallArtifact(glslang.artifact("glslang-default-resource-limits"), options).step);
	step.dependOn(&b.addInstallArtifact(glslang.artifact("SPIRV"), options).step);
	step.dependOn(&b.addInstallArtifact(glslang.artifact("SPIRV-Tools"), options).step);
	step.dependOn(&b.addInstallArtifact(glslang.artifact("SPIRV-Tools-opt"), options).step);

	return c_lib;
}

fn runChild(step: *std.Build.Step, argv: []const []const u8) !void {
	const allocator = step.owner.allocator;
	const result = try std.process.Child.run(.{.allocator = allocator, .argv = argv});
	try std.io.getStdOut().writeAll(result.stdout);
	try std.io.getStdErr().writeAll(result.stderr);
	allocator.free(result.stdout);
	allocator.free(result.stderr);
}

fn packageFunction(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
	const base: []const []const u8 = &.{"tar", "-czf"};
	try runChild(step, base ++ .{"zig-out/cubyz_deps_x86_64-windows-gnu.tar.gz", "zig-out/lib/cubyz_deps_x86_64-windows-gnu.lib", "zig-out/lib/cubyz_deps_x86_64-windows-gnu"});
	try runChild(step, base ++ .{"zig-out/cubyz_deps_aarch64-windows-gnu.tar.gz", "zig-out/lib/cubyz_deps_aarch64-windows-gnu.lib", "zig-out/lib/cubyz_deps_aarch64-windows-gnu"});
	try runChild(step, base ++ .{"zig-out/cubyz_deps_x86_64-linux-musl.tar.gz", "zig-out/lib/libcubyz_deps_x86_64-linux-musl.a", "zig-out/lib/cubyz_deps_x86_64-linux-musl"});
	try runChild(step, base ++ .{"zig-out/cubyz_deps_aarch64-linux-musl.tar.gz", "zig-out/lib/libcubyz_deps_aarch64-linux-musl.a", "zig-out/lib/cubyz_deps_aarch64-linux-musl"});
	try runChild(step, base ++ .{"zig-out/cubyz_deps_x86_64-macos-none.tar.gz", "zig-out/lib/libcubyz_deps_x86_64-macos-none.a", "zig-out/lib/cubyz_deps_x86_64-macos-none"});
	try runChild(step, base ++ .{"zig-out/cubyz_deps_aarch64-macos-none.tar.gz", "zig-out/lib/libcubyz_deps_aarch64-macos-none.a", "zig-out/lib/cubyz_deps_aarch64-macos-none"});
	try runChild(step, base ++ .{"zig-out/cubyz_deps_headers.tar.gz", "zig-out/include"});
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
	const buildStep = b.step("build_all", "Build all targets for distribution");
	releaseStep.dependOn(buildStep);

	for (targets) |target| {
		const t = b.resolveTargetQuery(target);
		const name = t.result.linuxTriple(b.allocator) catch unreachable;
		const subStep = b.step(name, b.fmt("Build only {s}", .{name}));
		const deps = b.fmt("cubyz_deps_{s}", .{name});
		const c_lib = makeCubyzLibs(b, subStep, deps, t, .ReleaseSmall, c_flags);
		const install = b.addInstallArtifact(c_lib, .{});

		subStep.dependOn(&install.step);
		buildStep.dependOn(subStep);
	}

	{
		const name = preferredTarget.result.linuxTriple(b.allocator) catch unreachable;
		const c_lib = makeCubyzLibs(b, nativeStep, b.fmt("cubyz_deps_{s}", .{name}), preferredTarget, preferredOptimize, c_flags);
		const install = b.addInstallArtifact(c_lib, .{});

		nativeStep.dependOn(&install.step);
	}

	{
		const step = try b.allocator.create(std.Build.Step);
		step.* = std.Build.Step.init(.{
			.name = "package",
			.makeFn = &packageFunction,
			.owner = b,
			.id = .custom,
		});
		step.dependOn(buildStep);
		releaseStep.dependOn(step);
	}

	// Alias the default `zig build` to only build native target.
	// Run `zig build release` to build all targets.
	b.getInstallStep().dependOn(nativeStep);
}
