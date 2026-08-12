const math = @import("math.zig");

pub const Camera = struct {
    pub const Perspective = struct {
        fov_y_radians: f32,
        aspect_ratio: f32,
        near: f32,
        far: f32,
        convention: math.ProjectionConvention,
    };

    pub const Orthographic = struct {
        left: f32,
        right: f32,
        bottom: f32,
        top: f32,
        near: f32,
        far: f32,
        convention: math.ProjectionConvention,
    };

    pub const Projection = union(enum) {
        perspective: Perspective,
        orthographic: Orthographic,
    };

    position: math.Vec3,
    target: math.Vec3,
    up: math.Vec3 = math.Vec3.unit_y,
    projection: Projection,

    pub fn view(self: Camera) math.Mat4 {
        return math.Mat4.lookAt(self.position, self.target, self.up, self.projectionConvention().handedness);
    }

    pub fn projectionMatrix(self: Camera) math.Mat4 {
        return switch (self.projection) {
            .perspective => |perspective| math.Mat4.perspective(
                perspective.fov_y_radians,
                perspective.aspect_ratio,
                perspective.near,
                perspective.far,
                perspective.convention,
            ),
            .orthographic => |orthographic| math.Mat4.orthographic(
                orthographic.left,
                orthographic.right,
                orthographic.bottom,
                orthographic.top,
                orthographic.near,
                orthographic.far,
                orthographic.convention,
            ),
        };
    }

    pub fn viewProjection(self: Camera) math.Mat4 {
        return math.Mat4.mul(self.projectionMatrix(), self.view());
    }

    pub fn projectionConvention(self: Camera) math.ProjectionConvention {
        return switch (self.projection) {
            .perspective => |perspective| perspective.convention,
            .orthographic => |orthographic| orthographic.convention,
        };
    }
};
