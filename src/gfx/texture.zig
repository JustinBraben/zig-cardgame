const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.texture);
const assert = std.debug.assert;
const zigimg = @import("zigimg");

const core = @import("mach").core;
const gpu = core.gpu;

pub const Texture = struct {
    allocator: Allocator,
    handle: *gpu.Texture,
    view_handle: *gpu.TextureView,
    sampler_handle: *gpu.Sampler,
    image: zigimg.Image,

    pub const TextureOptions = struct {
        address_mode: gpu.Sampler.AddressMode = .clamp_to_edge,
        filter: gpu.FilterMode = .nearest,
        format: gpu.Texture.Format = .rgba8_unorm,
        storage_binding: bool = false,
    };

    pub fn createEmpty(allocator: Allocator, width: u32, height: u32, options: Texture.TextureOptions) !Texture {
        const width_convertted = @as(usize, @intCast(width));
        const height_convertted = @as(usize, @intCast(height));
        const image = try zigimg.Image.create(allocator, width_convertted, height_convertted, .rgba32);
        return create(allocator, image, options);
    }

    pub fn loadFromFilePath(allocator: Allocator, filePath: []const u8, options: Texture.TextureOptions) !Texture {
        const image = try zigimg.Image.fromFilePath(allocator, filePath);
        return create(allocator, image, .{ .address_mode = options.address_mode, .filter = options.filter });
    }

    pub fn create(allocator: Allocator, image: zigimg.Image, options: Texture.TextureOptions) !Texture {
        const img_size = gpu.Extent3D{ .width = @as(u32, @intCast(image.width)), .height = @as(u32, @intCast(image.height)) };
        std.debug.print("img width : {}, height : {}\n", .{ img_size.width, img_size.height });

        const texture_descriptor = .{
            .size = img_size,
            .format = options.format,
            .usage = .{
                .texture_binding = true,
                .copy_dst = true,
                .render_attachment = true,
                .storage_binding = options.storage_binding,
            },
        };

        const texture = core.device.createTexture(&texture_descriptor);

        const view_descriptor = .{
            .format = options.format,
            .dimension = .dimension_2d,
            .array_layer_count = 1,
        };

        const view = texture.createView(&view_descriptor);

        const queue = core.device.getQueue();

        const data_layout = gpu.Texture.DataLayout{
            .bytes_per_row = @as(u32, @intCast(image.width * 4)),
            .rows_per_image = @as(u32, @intCast(image.height)),
        };

        switch (image.pixels) {
            .rgba32 => |pixels| queue.writeTexture(&.{ .texture = texture }, &data_layout, &img_size, pixels),
            .rgb24 => |pixels| {
                const data = try rgb24ToRgba32(allocator, pixels);
                defer data.deinit(allocator);
                queue.writeTexture(&.{ .texture = texture }, &data_layout, &img_size, data.rgba32);
            },
            else => @panic("unsupported image color format"),
        }

        const sampler_descriptor = .{
            .address_mode_u = options.address_mode,
            .address_mode_v = options.address_mode,
            .address_mode_w = options.address_mode,
            .mag_filter = options.filter,
            .min_filter = options.filter,
        };

        const sampler = core.device.createSampler(&sampler_descriptor);

        return .{
            .allocator = allocator,
            .handle = texture,
            .view_handle = view,
            .sampler_handle = sampler,
            .image = image,
        };
    }

    pub fn blit(self: *Texture, src_pixels: [][4]u8, dst_rect: [4]u32) void {
        const x = @as(usize, @intCast(dst_rect[0]));
        const y = @as(usize, @intCast(dst_rect[1]));
        const width = @as(usize, @intCast(dst_rect[2]));
        const height = @as(usize, @intCast(dst_rect[3]));

        const texture_width = @as(usize, @intCast(self.image.width));

        var starting_y = y;
        var starting_hieght = height;

        var dst_pixels = @as([*][4]u8, @ptrCast(self.image.pixels.asBytes().ptr))[0 .. self.image.pixels.asBytes().len / 4];

        var data = dst_pixels[(x + starting_y * texture_width)..(x + starting_y * texture_width + width)];
        var src_y: usize = 0;
        while (starting_hieght > 0) : (starting_hieght -= 1) {
            const src_row = src_pixels[(src_y * width) .. (src_y * width) + width];
            @memcpy(data, src_row);

            // next row and move our to it as well
            src_y += 1;
            starting_y += 1;
            data = dst_pixels[(x + starting_y * texture_width)..(x + starting_y * texture_width + width)];
        }
    }

    pub fn deinit(self: *Texture) void {
        self.handle.release();
        self.view_handle.release();
        self.sampler_handle.release();
        self.image.deinit();
    }
};

fn rgb24ToRgba32(allocator: std.mem.Allocator, in: []zigimg.color.Rgb24) !zigimg.color.PixelStorage {
    const out = try zigimg.color.PixelStorage.init(allocator, .rgba32, in.len);
    var i: usize = 0;
    while (i < in.len) : (i += 1) {
        out.rgba32[i] = zigimg.color.Rgba32{ .r = in[i].r, .g = in[i].g, .b = in[i].b, .a = 255 };
    }
    return out;
}
