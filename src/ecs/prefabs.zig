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
        const c1 = world.create();
        world.add(c1, Position{.x = 0, .y = 0});
        world.add(c1, CardSuit.Hearts);

        const c2 = world.create();
        world.add(c2, Position{.x = 1, .y = 1});
        world.add(c2, CardSuit.Spades);

        _ = self;
    }
};