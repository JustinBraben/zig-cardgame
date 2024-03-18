const std = @import("std");
const Allocator = std.mem.Allocator;
const Components =  @import("components.zig");
const Position = Components.Position;
const CardSuit = Components.CardSuit;
const ecs = @import("zig-ecs");
const Registry = ecs.Registry;

pub const Prefabs = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !Prefabs {
        return Prefabs{ 
            .allocator = allocator,
        };
    }

    pub fn create(self: *Prefabs, world: *Registry) void {
        const entity = world.create();
        world.add(entity, Position{.x = 0, .y = 0});
        world.add(entity, CardSuit.Hearts);

        _ = self;
    }
};