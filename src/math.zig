const std = @import("std");

pub const Handedness = enum {
    right,
    left,
};

pub const DepthRange = enum {
    zero_to_one,
    negative_one_to_one,
};

pub const ProjectionConvention = struct {
    handedness: Handedness,
    depth_range: DepthRange,
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero: Vec3 = .{ .x = 0, .y = 0, .z = 0 };
    pub const unit_x: Vec3 = .{ .x = 1, .y = 0, .z = 0 };
    pub const unit_y: Vec3 = .{ .x = 0, .y = 1, .z = 0 };
    pub const unit_z: Vec3 = .{ .x = 0, .y = 0, .z = 1 };

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, scalar: f32) Vec3 {
        return .{ .x = v.x * scalar, .y = v.y * scalar, .z = v.z * scalar };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(dot(v, v));
    }

    /// `v` must not have zero length.
    pub fn normalize(v: Vec3) Vec3 {
        std.debug.assert(v != zero);
        return scale(v, 1 / length(v));
    }
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const zero: Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };

    pub fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }
};

/// A column-major 4x4 matrix. Elements are indexed as `m[column * 4 + row]`.
/// Vectors are column vectors and transform as `matrix * vector`.
pub const Mat4 = extern struct {
    m: [16]f32,

    pub const identity: Mat4 = .{ .m = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    } };

    pub fn fromColumns(c0: Vec4, c1: Vec4, c2: Vec4, c3: Vec4) Mat4 {
        return .{ .m = .{
            c0.x, c0.y, c0.z, c0.w,
            c1.x, c1.y, c1.z, c1.w,
            c2.x, c2.y, c2.z, c2.w,
            c3.x, c3.y, c3.z, c3.w,
        } };
    }

    pub fn at(matrix: Mat4, column: usize, row: usize) f32 {
        return matrix.m[column * 4 + row];
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;
        inline for (0..4) |column| {
            inline for (0..4) |row| {
                result.m[column * 4 + row] =
                    a.m[row] * b.m[column * 4] +
                    a.m[4 + row] * b.m[column * 4 + 1] +
                    a.m[8 + row] * b.m[column * 4 + 2] +
                    a.m[12 + row] * b.m[column * 4 + 3];
            }
        }
        return result;
    }

    pub fn mulVec4(matrix: Mat4, vector: Vec4) Vec4 {
        return .{
            .x = matrix.m[0] * vector.x + matrix.m[4] * vector.y + matrix.m[8] * vector.z + matrix.m[12] * vector.w,
            .y = matrix.m[1] * vector.x + matrix.m[5] * vector.y + matrix.m[9] * vector.z + matrix.m[13] * vector.w,
            .z = matrix.m[2] * vector.x + matrix.m[6] * vector.y + matrix.m[10] * vector.z + matrix.m[14] * vector.w,
            .w = matrix.m[3] * vector.x + matrix.m[7] * vector.y + matrix.m[11] * vector.z + matrix.m[15] * vector.w,
        };
    }

    /// `eye` and `target` must differ, and `up` must not be parallel to the view direction.
    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3, handedness: Handedness) Mat4 {
        std.debug.assert(eye != target);

        const forward = Vec3.normalize(Vec3.sub(target, eye));
        const z_axis = switch (handedness) {
            .right => Vec3.scale(forward, -1),
            .left => forward,
        };
        const x_axis_unnormalized = Vec3.cross(up, z_axis);
        std.debug.assert(x_axis_unnormalized != Vec3.zero);
        const x_axis = Vec3.normalize(x_axis_unnormalized);
        const y_axis = Vec3.cross(z_axis, x_axis);

        return fromColumns(
            .{ .x = x_axis.x, .y = y_axis.x, .z = z_axis.x, .w = 0 },
            .{ .x = x_axis.y, .y = y_axis.y, .z = z_axis.y, .w = 0 },
            .{ .x = x_axis.z, .y = y_axis.z, .z = z_axis.z, .w = 0 },
            .{
                .x = -Vec3.dot(x_axis, eye),
                .y = -Vec3.dot(y_axis, eye),
                .z = -Vec3.dot(z_axis, eye),
                .w = 1,
            },
        );
    }

    /// `fov_y_radians` must be in `(0, pi)`, `aspect_ratio` and `near` must
    /// be positive, and `far` must be greater than `near`.
    pub fn perspective(fov_y_radians: f32, aspect_ratio: f32, near: f32, far: f32, convention: ProjectionConvention) Mat4 {
        std.debug.assert(fov_y_radians > 0 and fov_y_radians < std.math.pi);
        std.debug.assert(aspect_ratio > 0);
        std.debug.assert(near > 0);
        std.debug.assert(far > near);

        const focal_length = 1 / @tan(fov_y_radians / 2);
        const x_scale = focal_length / aspect_ratio;
        const y_scale = focal_length;

        const z = switch (convention.handedness) {
            .right => switch (convention.depth_range) {
                .zero_to_one => .{ far / (near - far), far * near / (near - far), -1.0 },
                .negative_one_to_one => .{ (far + near) / (near - far), 2 * far * near / (near - far), -1.0 },
            },
            .left => switch (convention.depth_range) {
                .zero_to_one => .{ far / (far - near), -far * near / (far - near), 1.0 },
                .negative_one_to_one => .{ (far + near) / (far - near), -2 * far * near / (far - near), 1.0 },
            },
        };

        return fromColumns(
            .{ .x = x_scale, .y = 0, .z = 0, .w = 0 },
            .{ .x = 0, .y = y_scale, .z = 0, .w = 0 },
            .{ .x = 0, .y = 0, .z = z[0], .w = z[2] },
            .{ .x = 0, .y = 0, .z = z[1], .w = 0 },
        );
    }

    /// `left`, `right`, `bottom`, `top`, `near`, and `far` must describe a
    /// non-zero volume, with `far` greater than `near`.
    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32, convention: ProjectionConvention) Mat4 {
        std.debug.assert(left != right);
        std.debug.assert(bottom != top);
        std.debug.assert(near > 0);
        std.debug.assert(far > near);

        const x_scale = 2 / (right - left);
        const y_scale = 2 / (top - bottom);
        const x_offset = -(right + left) / (right - left);
        const y_offset = -(top + bottom) / (top - bottom);

        const z = switch (convention.handedness) {
            .right => switch (convention.depth_range) {
                .zero_to_one => .{ 1 / (near - far), near / (near - far) },
                .negative_one_to_one => .{ 2 / (near - far), (far + near) / (near - far) },
            },
            .left => switch (convention.depth_range) {
                .zero_to_one => .{ 1 / (far - near), -near / (far - near) },
                .negative_one_to_one => .{ 2 / (far - near), -(far + near) / (far - near) },
            },
        };

        return fromColumns(
            .{ .x = x_scale, .y = 0, .z = 0, .w = 0 },
            .{ .x = 0, .y = y_scale, .z = 0, .w = 0 },
            .{ .x = 0, .y = 0, .z = z[0], .w = 0 },
            .{ .x = x_offset, .y = y_offset, .z = z[1], .w = 1 },
        );
    }
};
