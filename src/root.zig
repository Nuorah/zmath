const std = @import("std");
pub const math = @import("math.zig");
pub const camera = @import("camera.zig");

test {
    std.testing.refAllDecls(@This());
}
