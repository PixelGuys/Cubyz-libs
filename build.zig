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

pub fn addVulkan(b: *std.Build, c_lib: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, flags: []const []const u8) void {
	const headers = b.dependency("Vulkan-Headers", .{});
	const loader = b.dependency("Vulkan-Loader", .{});

	// NOTE(blackedout): How to compile the Vulkan loader is taken from the CMakeLists of that project.
	// This zig build is very incomplete but somehow still works on macOS
	const normalLoaderSources = [_][]const u8{
		"allocation.c",
		"cJSON.c",
		"debug_utils.c",
		"extension_manual.c",
		"loader_environment.c",
		"gpa_helper.c",
		"loader.c",
		"log.c",
		"loader_json.c",
		"settings.c",
		"terminator.c",
		"trampoline.c",
		"unknown_function_handling.c",
		"wsi.c"
	};

	const win32LoaderSources = [_][]const u8{
		"loader_windows.c",
		"dirent_on_windows.c",
	};

	const linuxLoaderSources = [_][]const u8{
		"loader_linux.c",
	};

	var all_flags = std.array_list.Managed([]const u8).init(b.allocator);
	all_flags.appendSlice(flags) catch unreachable;
	switch(target.result.os.tag) {
		.windows => {
			all_flags.append("-DVK_USE_PLATFORM_WIN32_KHR") catch unreachable;
		},
		.linux, .freebsd, .openbsd, .dragonfly => {
		},
		.ios => {
			all_flags.append("-DVK_USE_PLATFORM_METAL_EXT") catch unreachable;
			all_flags.append("-VK_USE_PLATFORM_IOS_MVK") catch unreachable;
		},
		.macos => {
			all_flags.append("-DVK_USE_PLATFORM_METAL_EXT") catch unreachable;
			all_flags.append("-DVK_USE_PLATFORM_MACOS_MVK") catch unreachable;
		},
		else => {}
	}
	all_flags.append("-DVK_ENABLE_BETA_EXTENSIONS") catch unreachable;

	// NOTE(blackedout): Should really be if UNIX
	if(target.result.os.tag == .linux or target.result.os.tag == .macos) {
		all_flags.append("-DFALLBACK_CONFIG_DIRS=\"/etc/xdg\"") catch unreachable;
		all_flags.append("-DFALLBACK_DATA_DIRS=\"/usr/local/share:/usr/share\"") catch unreachable;
		all_flags.append("-DSYSCONFDIR=\"/etc\"") catch unreachable;
	}

	c_lib.addIncludePath(headers.path("include"));
	c_lib.addIncludePath(loader.path("loader"));
	c_lib.addIncludePath(loader.path("loader/generated"));
	c_lib.installHeadersDirectory(headers.path("include"), "", .{});
	c_lib.addCSourceFiles(.{ .root = loader.path("loader"), .files = &normalLoaderSources, .flags = all_flags.items, });
	switch(target.result.os.tag) {
		.windows => {
			c_lib.addCSourceFiles(.{ .root = loader.path("loader"), .files = &win32LoaderSources, .flags = all_flags.items, });
		},
		.linux, .freebsd, .openbsd, .dragonfly => {
			c_lib.addCSourceFiles(.{ .root = loader.path("loader"), .files = &linuxLoaderSources, .flags = all_flags.items, });
		},
		.macos => {
		},
		else => {}
	}

	// NOTE(blackedout): Add the MoltenVK binary and JSON manifest file
	if(target.result.os.tag == .macos) {
		const moltenvk = b.dependency("MoltenVK-macos", .{});
		const moltenvkLibPath = moltenvk.path("MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib");
		const moltenvkJsonPath = moltenvk.path("MoltenVK/dynamic/dylib/macOS/MoltenVK_icd.json");
		b.getInstallStep().dependOn(&b.addInstallLibFile(moltenvkLibPath, "libMoltenVK.dylib").step);
		b.getInstallStep().dependOn(&b.addInstallLibFile(moltenvkJsonPath, "MoltenVK_icd.json").step);
	}
}

pub fn makeVulkanLayers(b: *std.Build, parentStep: *std.Build.Step, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, flags: []const []const u8) *std.Build.Step.InstallArtifact {
	const layerslib = b.addLibrary(.{
		.name = "VkLayer_khronos_validation",
		.root_module = b.createModule(.{
			.target = target,
			.optimize = optimize,
		}),
		.linkage = .dynamic
	});

	const headers = b.dependency("Vulkan-Headers", .{});
	const validationLayers = b.dependency("Vulkan-ValidationLayers", .{});
	const utilityLibraries = b.dependency("Vulkan-Utility-Libraries", .{});

	// NOTE(blackedout): How to compile the Vulkan validation layers is taken from the CMakeLists of that project.
	// This zig build is very incomplete but somehow still works on macOS
	const layerSources = [_][]const u8{
		"error_message/logging.cpp",
		"error_message/error_location.cpp",
		"vulkan/generated/error_location_helper.cpp",
		"vulkan/generated/feature_requirements_helper.cpp",
		"vulkan/generated/pnext_chain_extraction.cpp",
		"vulkan/generated/vk_function_pointers.cpp",
		"vulkan/generated/vk_dispatch_table_helper.cpp",
		"vulkan/generated/vk_object_types.cpp",
		"vulkan/generated/vk_extension_helper.cpp",
		"utils/convert_utils.cpp",
		"utils/dispatch_utils.cpp",
		"utils/file_system_utils.cpp",
		"utils/hash_util.cpp",
		"utils/image_utils.cpp",
		"utils/image_layout_utils.cpp",
		"utils/vk_layer_extension_utils.cpp",
		"utils/keyboard.cpp",
		"utils/ray_tracing_utils.cpp",
		"utils/sync_utils.cpp",
		"utils/text_utils.cpp",
		"utils/vk_struct_compare.cpp",
		"vk_layer_config.cpp",

		"best_practices/bp_buffer.cpp",
		"best_practices/bp_cmd_buffer.cpp",
		"best_practices/bp_cmd_buffer_nv.cpp",
		"best_practices/bp_copy_blit_resolve.cpp",
		"best_practices/bp_descriptor.cpp",
		"best_practices/bp_device_memory.cpp",
		"best_practices/bp_drawdispatch.cpp",
		"best_practices/bp_framebuffer.cpp",
		"best_practices/bp_image.cpp",
		"best_practices/bp_instance_device.cpp",
		"best_practices/bp_pipeline.cpp",
		"best_practices/bp_ray_tracing.cpp",
		"best_practices/bp_render_pass.cpp",
		"best_practices/bp_state_tracker.cpp",
		"best_practices/bp_state.cpp",
		"best_practices/bp_synchronization.cpp",
		"best_practices/bp_utils.cpp",
		"best_practices/bp_video.cpp",
		"best_practices/bp_wsi.cpp",
		"chassis/chassis_manual.cpp",
		"chassis/dispatch_object_manual.cpp",
		"containers/subresource_adapter.cpp",
		"core_checks/cc_android.cpp",
		"core_checks/cc_buffer.cpp",
		"core_checks/cc_cmd_buffer_dynamic.cpp",
		"core_checks/cc_cmd_buffer.cpp",
		"core_checks/cc_copy_blit_resolve.cpp",
		"core_checks/cc_data_graph.cpp",
		"core_checks/cc_descriptor.cpp",
		"core_checks/cc_device.cpp",
		"core_checks/cc_device_memory.cpp",
		"core_checks/cc_device_generated_commands.cpp",
		"core_checks/cc_drawdispatch.cpp",
		"core_checks/cc_external_object.cpp",
		"core_checks/cc_image.cpp",
		"core_checks/cc_image_layout.cpp",
		"core_checks/cc_pipeline_compute.cpp",
		"core_checks/cc_pipeline_graphics.cpp",
		"core_checks/cc_pipeline_ray_tracing.cpp",
		"core_checks/cc_pipeline.cpp",
		"core_checks/cc_query.cpp",
		"core_checks/cc_queue.cpp",
		"core_checks/cc_ray_tracing.cpp",
		"core_checks/cc_render_pass.cpp",
		"core_checks/cc_spirv.cpp",
		"core_checks/cc_shader_interface.cpp",
		"core_checks/cc_shader_object.cpp",
		"core_checks/cc_state_tracker.cpp",
		"core_checks/cc_submit.cpp",
		"core_checks/cc_sync_vuid_maps.cpp",
		"core_checks/cc_synchronization.cpp",
		"core_checks/cc_tensor.cpp",
		"core_checks/cc_video.cpp",
		"core_checks/cc_vuid_maps.cpp",
		"core_checks/cc_wsi.cpp",
		"core_checks/cc_ycbcr.cpp",
		"drawdispatch/descriptor_validator.cpp",
		"drawdispatch/drawdispatch_vuids.cpp",
		"error_message/spirv_logging.cpp",
		"external/vma/vma.cpp",
		"vulkan/generated/best_practices.cpp",
		"vulkan/generated/chassis.cpp",
		"vulkan/generated/valid_enum_values.cpp",
		"vulkan/generated/valid_flag_values.cpp",
		"vulkan/generated/command_validation.cpp",
		"vulkan/generated/deprecation.cpp",
		"vulkan/generated/device_features.cpp",
		"vulkan/generated/dynamic_state_helper.cpp",
		"vulkan/generated/feature_not_present.cpp",
		"vulkan/generated/dispatch_vector.cpp",
		"vulkan/generated/dispatch_object.cpp",
		"vulkan/generated/validation_object.cpp",
		"vulkan/generated/object_tracker.cpp",
		"vulkan/generated/spirv_grammar_helper.cpp",
		"vulkan/generated/spirv_validation_helper.cpp",
		"vulkan/generated/stateless_validation_helper.cpp",
		"vulkan/generated/sync_validation_types.cpp",
		"vulkan/generated/thread_safety.cpp",
		"vulkan/generated/gpuav_offline_spirv.cpp",
		"gpuav/core/gpuav_features.cpp",
		"gpuav/core/gpuav_record.cpp",
		"gpuav/core/gpuav_setup.cpp",
		"gpuav/core/gpuav_settings.cpp",
		"gpuav/core/gpuav_validation_pipeline.cpp",
		"gpuav/validation_cmd/gpuav_validation_cmd_common.cpp",
		"gpuav/validation_cmd/gpuav_draw.cpp",
		"gpuav/validation_cmd/gpuav_dispatch.cpp",
		"gpuav/validation_cmd/gpuav_trace_rays.cpp",
		"gpuav/validation_cmd/gpuav_copy_buffer_to_image.cpp",
		"gpuav/descriptor_validation/gpuav_descriptor_validation.cpp",
		"gpuav/descriptor_validation/gpuav_descriptor_set.cpp",
		"gpuav/debug_printf/debug_printf.cpp",
		"gpuav/error_message/gpuav_vuids.cpp",
		"gpuav/instrumentation/gpuav_shader_instrumentor.cpp",
		"gpuav/instrumentation/gpuav_instrumentation.cpp",
		"gpuav/instrumentation/buffer_device_address.cpp",
		"gpuav/instrumentation/descriptor_checks.cpp",
		"gpuav/instrumentation/post_process_descriptor_indexing.cpp",
		"gpuav/resources/gpuav_state_trackers.cpp",
		"gpuav/resources/gpuav_vulkan_objects.cpp",
		"object_tracker/object_tracker_utils.cpp",
		"state_tracker/buffer_state.cpp",
		"state_tracker/cmd_buffer_state.cpp",
		"state_tracker/data_graph_pipeline_session_state.cpp",
		"state_tracker/descriptor_sets.cpp",
		"state_tracker/device_generated_commands_state.cpp",
		"state_tracker/device_memory_state.cpp",
		"state_tracker/device_state.cpp",
		"state_tracker/fence_state.cpp",
		"state_tracker/image_layout_map.cpp",
		"state_tracker/image_state.cpp",
		"state_tracker/last_bound_state.cpp",
		"state_tracker/pipeline_layout_state.cpp",
		"state_tracker/pipeline_state.cpp",
		"state_tracker/pipeline_library_state.cpp",
		"state_tracker/semaphore_state.cpp",
		"state_tracker/state_object.cpp",
		"state_tracker/query_state.cpp",
		"state_tracker/tensor_state.cpp",
		"state_tracker/queue_state.cpp",
		"state_tracker/render_pass_state.cpp",
		"state_tracker/shader_instruction.cpp",
		"state_tracker/shader_module.cpp",
		"state_tracker/shader_object_state.cpp",
		"state_tracker/shader_stage_state.cpp",
		"state_tracker/state_tracker.cpp",
		"state_tracker/video_session_state.cpp",
		"state_tracker/wsi_state.cpp",
		"stateless/sl_buffer.cpp",
		"stateless/sl_cmd_buffer_dynamic.cpp",
		"stateless/sl_cmd_buffer.cpp",
		"stateless/sl_descriptor.cpp",
		"stateless/sl_device_generated_commands.cpp",
		"stateless/sl_device_memory.cpp",
		"stateless/sl_external_object.cpp",
		"stateless/sl_framebuffer.cpp",
		"stateless/sl_image.cpp",
		"stateless/sl_instance_device.cpp",
		"stateless/sl_pipeline.cpp",
		"stateless/sl_ray_tracing.cpp",
		"stateless/sl_render_pass.cpp",
		"stateless/sl_shader_object.cpp",
		"stateless/sl_spirv.cpp",
		"stateless/sl_synchronization.cpp",
		"stateless/sl_tensor.cpp",
		"stateless/sl_utils.cpp",
		"stateless/sl_vuid_maps.cpp",
		"stateless/sl_wsi.cpp",
		"sync/sync_access_context.cpp",
		"sync/sync_access_state.cpp",
		"sync/sync_barrier.cpp",
		"sync/sync_commandbuffer.cpp",
		"sync/sync_common.cpp",
		"sync/sync_error_messages.cpp",
		"sync/sync_image.cpp",
		"sync/sync_op.cpp",
		"sync/sync_renderpass.cpp",
		"sync/sync_reporting.cpp",
		"sync/sync_stats.cpp",
		"sync/sync_submit.cpp",
		"sync/sync_validation.cpp",
		"thread_tracker/thread_safety_validation.cpp",
		"utils/shader_utils.cpp",
		"layer_options.cpp"
	};

	const utilitySources = [_][]const u8{
		"layer/vk_layer_settings.cpp",
		"layer/vk_layer_settings_helper.cpp",
		"layer/layer_settings_manager.cpp",
		"layer/layer_settings_util.cpp",
		"vulkan/vk_safe_struct_core.cpp",
		"vulkan/vk_safe_struct_ext.cpp",
		"vulkan/vk_safe_struct_khr.cpp",
		"vulkan/vk_safe_struct_utils.cpp",
		"vulkan/vk_safe_struct_vendor.cpp",
		"vulkan/vk_safe_struct_manual.cpp"
	};

	const gpuavSpirvSources = [_][]const u8{
		"descriptor_indexing_oob_pass.cpp",
		"descriptor_class_general_buffer_pass.cpp",
		"descriptor_class_texel_buffer_pass.cpp",
		"buffer_device_address_pass.cpp",
		"ray_query_pass.cpp",
		"debug_printf_pass.cpp",
		"post_process_descriptor_indexing_pass.cpp",
		"vertex_attribute_fetch_oob.cpp",
		"log_error_pass.cpp",
		"function_basic_block.cpp",
		"module.cpp",
		"type_manager.cpp",
		"pass.cpp",
	};

	var all_flags = std.array_list.Managed([]const u8).init(b.allocator);
	all_flags.appendSlice(flags) catch unreachable;
	switch(target.result.os.tag) {
		.windows => {
			all_flags.append("-DVK_USE_PLATFORM_WIN32_KHR") catch unreachable;
		},
		.linux, .freebsd, .openbsd, .dragonfly => {
		},
		.ios => {
			all_flags.append("-DVK_USE_PLATFORM_METAL_EXT") catch unreachable;
			all_flags.append("-VK_USE_PLATFORM_IOS_MVK") catch unreachable;
		},
		.macos => {
			all_flags.append("-DVK_USE_PLATFORM_METAL_EXT") catch unreachable;
			all_flags.append("-DVK_USE_PLATFORM_MACOS_MVK") catch unreachable;
		},
		else => {}
	}
	all_flags.append("-DVK_ENABLE_BETA_EXTENSIONS") catch unreachable;

	const glslang = b.dependency("glslang", .{});
	const spirvHeaders = b.dependency("SPIRV-Headers", .{});
	const spirvTools = glslang.builder.dependency("SPIRV-Tools", .{});

	layerslib.addIncludePath(headers.path("include"));
	layerslib.addIncludePath(utilityLibraries.path("include"));
	layerslib.addIncludePath(spirvHeaders.path("include"));
	layerslib.addIncludePath(spirvTools.path("include"));
	layerslib.addIncludePath(validationLayers.path("layers"));
	layerslib.addIncludePath(validationLayers.path("layers/vulkan"));
	layerslib.addIncludePath(validationLayers.path("layers/external"));
	
	layerslib.addCSourceFiles(.{ .root = utilityLibraries.path("src"), .files = &utilitySources, .flags = all_flags.items, });
	layerslib.addCSourceFiles(.{ .root = validationLayers.path("layers"), .files = &layerSources, .flags = all_flags.items, });
	layerslib.addCSourceFiles(.{ .root = validationLayers.path("layers/gpuav/spirv"), .files = &gpuavSpirvSources, .flags = all_flags.items, });
	layerslib.linkLibrary(glslang.artifact("SPIRV-Tools"));
	layerslib.linkLibrary(glslang.artifact("SPIRV-Tools-opt"));

	const validationLayerJsonPath = validationLayers.path("layers/VkLayer_khronos_validation.json.in");
	parentStep.dependOn(&b.addInstallLibFile(validationLayerJsonPath, "VkLayer_khronos_validation.json").step);

	const install = b.addInstallArtifact(layerslib, .{});

	// NOTE(blackedout): Replace the layer name and lib path placeholders in the layer manifest JSON file AFTER these files have been installed
	const sedLayerName = b.addSystemCommand(&.{"sed", "-i", "", "s|@JSON_LAYER_NAME@|VK_LAYER_KHRONOS_validation|g"});
	const sedLayerLibPath = b.addSystemCommand(&.{"sed", "-i", "", "s|@JSON_LIBRARY_PATH@|./libVkLayer_khronos_validation.dylib|g"});
	sedLayerName.addFileArg(b.path("zig-out/lib/VkLayer_khronos_validation.json"));
	sedLayerLibPath.addFileArg(b.path("zig-out/lib/VkLayer_khronos_validation.json"));
	sedLayerName.step.dependOn(&install.step);
	sedLayerLibPath.step.dependOn(&install.step);

	parentStep.dependOn(&sedLayerName.step);
	parentStep.dependOn(&sedLayerLibPath.step);

	return install;
}

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

	const WinSys = enum {win32, x11, cocoa};

	// TODO: Wayland
	const ws: WinSys = switch(os) {
		.windows => .win32,
		.linux => .x11,
		.macos => .cocoa,
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
	var all_flags = std.array_list.Managed([]const u8).init(b.allocator);
	all_flags.appendSlice(flags) catch unreachable;
	all_flags.append(ws_flag) catch unreachable;
	if(os == .linux) {
		all_flags.append("-D_GNU_SOURCE") catch unreachable;
	}

	c_lib.addIncludePath(glfw.path("include"));
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
			.cocoa => &.{"cocoa_init.m", "cocoa_joystick.m", "cocoa_monitor.m", "cocoa_window.m", "nsgl_context.m"},
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

pub inline fn makeCubyzLibs(b: *std.Build, step: *std.Build.Step, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, flags: []const []const u8) *std.Build.Step.Compile {
	const c_lib = b.addLibrary(.{
		.name = name,
		.root_module = b.createModule(.{
			.target = target,
			.optimize = optimize,
		})
	});

	c_lib.addAfterIncludePath(b.path("include"));
	c_lib.installHeader(b.path("include/glad/gl.h"), "glad/gl.h");
	c_lib.installHeader(b.path("include/KHR/khrplatform.h"), "KHR/khrplatform.h");

	// NOTE(blackedout): glad for Vulkan is not needed on macOS since the loader is currently statically linked.
	// Whether or not glad can be used like Volk to bind the Vulkan functions directly to the driver, I don't know.
	if(target.result.os.tag != .macos) {
		c_lib.installHeader(b.path("include/glad/vulkan.h"), "glad/vulkan.h");
		c_lib.installHeader(b.path("include/vk_platform.h"), "vk_platform.h");
	}

	c_lib.installHeader(b.path("include/stb/stb_image_write.h"), "stb/stb_image_write.h");
	c_lib.installHeader(b.path("include/stb/stb_image.h"), "stb/stb_image.h");
	c_lib.installHeader(b.path("include/stb/stb_vorbis.h"), "stb/stb_vorbis.h");
	c_lib.installHeader(b.path("include/miniaudio.h"), "miniaudio.h");
	addFreetypeAndHarfbuzz(b, c_lib, target, flags);

	// NOTE(blackedout): `addVulkan` is only tested/needed on macOS so far
	if(target.result.os.tag == .macos) {
		addVulkan(b, c_lib, target, flags);
	}

	addGLFWSources(b, c_lib, target, flags);
	c_lib.addCSourceFile(.{.file = b.path("lib/gl.c"), .flags = flags});

	// NOTE(blackedout): See the above glad comment
	if(target.result.os.tag != .macos) {
		c_lib.addCSourceFile(.{.file = b.path("lib/vulkan.c"), .flags = flags});
	}

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
	try std.fs.File.stdout().writeAll(result.stdout);
	try std.fs.File.stderr().writeAll(result.stderr);
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

		if(t.result.os.tag == .macos) {
			const layersInstall = makeVulkanLayers(b, subStep, t, .ReleaseSmall, c_flags);
			subStep.dependOn(&layersInstall.step);
		}
		
		buildStep.dependOn(subStep);
	}

	{
		const name = preferredTarget.result.linuxTriple(b.allocator) catch unreachable;
		const c_lib = makeCubyzLibs(b, nativeStep, b.fmt("cubyz_deps_{s}", .{name}), preferredTarget, preferredOptimize, c_flags);
		const install = b.addInstallArtifact(c_lib, .{});

		nativeStep.dependOn(&install.step);

		if(preferredTarget.result.os.tag == .macos) {
			const layersInstall = makeVulkanLayers(b, nativeStep, preferredTarget, preferredOptimize, c_flags);
			nativeStep.dependOn(&layersInstall.step);
		}
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
