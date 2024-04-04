const std = @import("std");
const log = std.log.scoped(.build);
const mach = @import("mach");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const mach_dep = b.dependency("mach", .{
        .target = target,
        .optimize = optimize,

        // Since we're only using @import("mach").core, we can specify this to avoid
        // pulling in unneccessary dependencies.
        .core = true,
    });

    // This is a list of dependencies for the app. Add anything you want the app to be able to @import
    var deps = std.ArrayList(std.Build.Module.Import).init(b.allocator);
    for (b.available_deps) |dep| {
        // Skip mach dependency, as it's already included in the mach_dep
        if (!std.mem.eql(u8, dep[0], "mach")){
            const found_dep = b.dependency(dep[0], .{
                .target = target,
                .optimize = optimize,
            });
            try deps.append(std.Build.Module.Import{
                .name = dep[0],
                .module = found_dep.module(dep[0]),
            });
        }
    }

    const app = try mach.CoreApp.init(b, mach_dep.builder, .{
        .name = "myapp",
        .src = "src/main.zig",
        .target = target,
        .optimize = optimize,
        .deps = deps.items,
    });
    if (b.args) |args| app.run.addArgs(args);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&app.run.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // This adds the `mach` dependency to the unit tests.
    unit_tests.root_module.addImport("mach", mach_dep.module("mach"));
    // The rest of the deps can be added through a loop
    for (deps.items) |dep| {
        unit_tests.root_module.addImport(dep.name, dep.module);
    }

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}