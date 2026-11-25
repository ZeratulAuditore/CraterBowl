"""Build the two character GLBs with Blender 4.3.

blender -b -t 2 -P tools/characters/build_uniforms.py -- /path/to/professional-football-player.glb
"""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/characters"
UP = Vector((0, 1, 0))


def blender_point(point):
    x, y, z = point
    return (x, -z, y)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(name):
    bpy.ops.export_scene.gltf(
        filepath=str(ASSETS / name), export_format="GLB",
        export_animations=False, export_yup=True,
    )


def material(name, rgb, roughness=0.7, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*rgb, 1)
    return mat


def open_helmet(source):
    reset()
    bpy.ops.import_scene.gltf(filepath=str(source))
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or not obj.name.startswith(
            ("Football helmet shell", "Football face mask", "Football chin strap")
        ):
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        matrix = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world.identity()
        obj.data.transform(matrix)
        center = Vector(blender_point((0, 1.545, 0.135)))
        target = Vector(blender_point((0, 0.135, -0.012)))
        for vert in obj.data.vertices:
            vert.co = (vert.co - center) * 1.36 + target
    shell = next(obj for obj in bpy.context.scene.objects
                 if obj.name.startswith("Football helmet shell"))
    for obj in bpy.context.scene.objects:
        old = obj.data.materials[0]
        node = old.node_tree.nodes.get("Principled BSDF")
        base = node.inputs["Base Color"]
        # The source equipment uses solid-color swatch textures.
        image = base.links[0].from_node.image
        rgb = tuple(image.pixels[:3])
        name = "Shell" if obj == shell else old.name
        mat = bpy.data.materials.get(name + " Color")
        if mat is None:
            mat = material(name + " Color", rgb, node.inputs["Roughness"].default_value,
                           node.inputs["Metallic"].default_value)
        obj.data.materials[0] = mat
    shell.data.materials[0].name = "Shell"
    stripe_vertices = []
    for i in range(21):
        depth = -0.11 + 0.011 * i
        for x in (-0.017, 0.017):
            hit, point, normal, _ = shell.ray_cast(
                Vector(blender_point((x, 0.5, depth))), Vector((0, 0, -1))
            )
            if not hit:
                raise ValueError("Stripe crossed the edge of the helmet")
            stripe_vertices.append(point + normal * 0.0018)
    stripe_faces = [(i + 2, i + 3, i + 1, i) for i in range(0, 40, 2)]
    stripe_mesh = bpy.data.meshes.new("HelmetStripe")
    stripe_mesh.from_pydata(stripe_vertices, [], stripe_faces)
    stripe_mesh.materials.append(material("HelmetStripe", (0.8, 0.8, 0.8), 0.25))
    stripe = bpy.data.objects.new("HelmetStripe", stripe_mesh)
    bpy.context.collection.objects.link(stripe)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = shell
    bpy.ops.object.join()
    shell.name = "InnersceneHelmet"
    export("InnersceneHelmet.glb")


class Uniform:
    def __init__(self):
        self.vertices = []
        self.weights = []
        self.faces = []
        self.material_ids = []
        self.materials = [
            material("Jersey", (0.035, 0.32, 0.48)),
            material("Pants", (0.045, 0.065, 0.095)),
            material("Undersuit", (0.025, 0.035, 0.055)),
            material("Trim", (0.73, 0.87, 0.9)),
            material("Shell", (0.02, 0.11, 0.19), 0.25, 0.32),
            material("HelmetStripe", (0.62, 0.86, 0.95), 0.28, 0.28),
            material("Visor", (0.012, 0.025, 0.04), 0.17, 0.38),
            material("Cage", (0.28, 0.38, 0.48), 0.33, 0.7),
            material("Face", (0.22, 0.11, 0.07)),
        ]

    def loft(self, rings, mat, axis=(0, 1, 0), sides=12, power=1.0):
        """Each ring supplies center, two radii, and a bone-weight dictionary."""
        axis = Vector(axis).normalized()
        across = Vector((1, 0, 0)) if abs(axis.dot(UP)) > 0.9 else UP
        depth = axis.cross(across).normalized()
        across = depth.cross(axis).normalized()
        start = len(self.vertices)
        for center, width, thickness, weights in rings:
            for i in range(sides):
                angle = math.tau * i / sides
                c, s = math.cos(angle), math.sin(angle)
                point = Vector(center)
                point += across * width * math.copysign(abs(c) ** power, c)
                point += depth * thickness * math.copysign(abs(s) ** power, s)
                self.vertices.append(blender_point(point))
                self.weights.append(weights)
        faces = [tuple(start + i for i in reversed(range(sides)))]
        for ring in range(len(rings) - 1):
            lower = start + ring * sides
            for i in range(sides):
                j = (i + 1) % sides
                faces.append((lower + i, lower + j, lower + j + sides, lower + i + sides))
        end = start + (len(rings) - 1) * sides
        faces.append(tuple(end + i for i in range(sides)))
        self.faces.extend(faces)
        self.material_ids.extend([mat] * len(faces))

    def volume(self, bone, mat, profiles, axis=(0, 1, 0), sides=12, power=1.0):
        self.loft(
            [(center, width, depth, {bone: 1.0}) for center, width, depth in profiles],
            mat, axis, sides, power,
        )

    def tube(self, points, radius, bone, mat):
        for a, b in zip(points, points[1:]):
            self.volume(bone, mat, [(a, radius, radius), (b, radius, radius)],
                        axis=Vector(b) - Vector(a), sides=8)

    def torso(self):
        self.loft([
            ((0, 0.889, -0.022), 0.199, 0.136, {"pelvis": 1}),
            ((0, 1.01, -0.024), 0.182, 0.124, {"pelvis": 0.5, "spine_01": 0.5}),
            ((0, 1.18, -0.006), 0.19, 0.146, {"spine_02": 1}),
            ((0, 1.37, -0.015), 0.265, 0.177, {"spine_03": 1}),
            ((0, 1.468, -0.024), 0.228, 0.150, {"spine_03": 1}),
            ((0, 1.53, -0.02), 0.108, 0.102, {"spine_03": 1}),
        ], 0, sides=16, power=0.63)
        self.volume("pelvis", 1, [
            ((0, 0.775, -0.017), 0.157, 0.102),
            ((0, 0.86, -0.02), 0.185, 0.125),
            ((0, 0.97, -0.03), 0.167, 0.112),
        ], power=0.68)
        self.volume("spine_03", 3, [
            ((0, 1.504, 0), 0.107, 0.091), ((0, 1.542, 0), 0.081, 0.078),
        ])
        self.volume("neck_01", 2, [
            ((0, 1.49, 0), 0.069, 0.073), ((0, 1.64, 0.005), 0.069, 0.073),
        ])

    def limbs(self, sign, side):
        upper, lower, hand = (f"{part}_{side}" for part in ("upperarm", "lowerarm", "hand"))
        axis = (sign, 0, 0)
        arm = lambda x: (sign * x, 1.44, -0.065)
        self.loft([
            (arm(0.158), 0.109, 0.119, {"spine_03": 0.85, upper: 0.15}),
            (arm(0.257), 0.124, 0.127, {upper: 1}),
            (arm(0.331), 0.094, 0.100, {upper: 1}),
            (arm(0.366), 0.071, 0.077, {upper: 1}),
        ], 0, axis, power=0.72)
        self.volume(upper, 3, [(arm(0.342), 0.087, 0.093), (arm(0.359), 0.078, 0.084)], axis)
        self.loft([
            (arm(0.325), 0.078, 0.076, {upper: 1}),
            (arm(0.426), 0.056, 0.058, {upper: 1}),
            (arm(0.466), 0.055, 0.055, {upper: 0.5, lower: 0.5}),
            (arm(0.535), 0.068, 0.06, {lower: 1}),
            (arm(0.72), 0.039, 0.045, {lower: 1}),
            (arm(0.75), 0.039, 0.048, {hand: 1}),
        ], 2, axis)
        self.volume(hand, 3, [
            (arm(0.70), 0.037, 0.044), (arm(0.77), 0.048, 0.06),
            (arm(0.86), 0.047, 0.055), (arm(0.903), 0.029, 0.040),
        ], axis, power=0.75)
        thumb_start = Vector((sign * 0.763, 1.438, -0.025))
        thumb_tip = Vector((sign * 0.832, 1.423, 0.013))
        self.volume(hand, 3, [(thumb_start, 0.024, 0.023), (thumb_tip, 0.016, 0.017)],
                    axis=thumb_tip - thumb_start)

        thigh, calf, foot, ball = (f"{part}_{side}" for part in ("thigh", "calf", "foot", "ball"))
        x = sign * 0.089
        self.loft([
            ((x, 0.49, 0.001), 0.067, 0.065, {calf: 0.8, thigh: 0.2}),
            ((x, 0.54, 0.009), 0.075, 0.087, {calf: 0.45, thigh: 0.55}),
            ((x, 0.69, -0.001), 0.087, 0.108, {thigh: 1}),
            ((x, 0.86, -0.012), 0.099, 0.113, {thigh: 1}),
            ((x, 0.94, -0.018), 0.093, 0.095, {thigh: 0.5, "pelvis": 0.5}),
        ], 1, power=0.83)
        self.volume(thigh, 3, [
            ((x + sign * 0.066, 0.62, 0.03), 0.015, 0.028),
            ((x + sign * 0.085, 0.77, 0), 0.016, 0.036),
            ((x + sign * 0.086, 0.86, -0.006), 0.015, 0.031),
        ])
        self.loft([
            ((x, 0.085, -0.032), 0.044, 0.049, {foot: 1}),
            ((x, 0.16, -0.029), 0.048, 0.052, {calf: 1}),
            ((x, 0.35, -0.012), 0.065, 0.07, {calf: 1}),
            ((x, 0.49, -0.005), 0.062, 0.065, {calf: 1}),
            ((x, 0.53, -0.004), 0.064, 0.063, {calf: 0.5, thigh: 0.5}),
        ], 2)
        self.loft([
            ((x, 0.058, -0.089), 0.051, 0.044, {foot: 1}),
            ((x, 0.059, -0.038), 0.063, 0.058, {foot: 1}),
            ((x, 0.045, 0.073), 0.063, 0.040, {foot: 0.7, ball: 0.3}),
            ((x, 0.038, 0.154), 0.063, 0.027, {ball: 1}),
            ((x, 0.037, 0.197), 0.042, 0.022, {ball: 1}),
        ], 2, (0, 0, 1), power=0.62)

    def helmet(self):
        self.volume("Head", 8, [
            ((0, 1.562, 0.016), 0.058, 0.05),
            ((0, 1.625, 0.033), 0.087, 0.091),
            ((0, 1.735, 0.01), 0.092, 0.093),
        ])
        self.volume("Head", 4, [
            ((0, 1.699, -0.024), 0.126, 0.108),
            ((0, 1.752, -0.014), 0.146, 0.137),
            ((0, 1.838, -0.02), 0.129, 0.121),
            ((0, 1.884, -0.019), 0.077, 0.074),
            ((0, 1.895, -0.018), 0.039, 0.038),
        ], sides=16, power=0.67)
        self.volume("Head", 6, [
            ((0, 1.665, 0.106), 0.092, 0.031),
            ((0, 1.724, 0.102), 0.122, 0.041),
            ((0, 1.753, 0.092), 0.115, 0.034),
        ], sides=16, power=0.48)
        for x in (-0.026, 0.026):
            self.tube([(x, 1.749, 0.127), (x, 1.839, 0.101), (x, 1.885, 0.053),
                       (x, 1.899, -0.018), (x, 1.881, -0.094)], 0.006, "Head", 5)
        for y in (1.612, 1.65):
            self.tube([(-0.127, y + 0.054, 0.014), (-0.102, y + 0.003, 0.106),
                       (-0.07, y, 0.152), (0.07, y, 0.152), (0.102, y + 0.003, 0.106),
                       (0.127, y + 0.054, 0.014)], 0.008, "Head", 7)
        for x in (-0.06, 0.06):
            self.tube([(x, 1.611, 0.151), (x, 1.684, 0.151)], 0.007, "Head", 7)

    def mesh(self, rig):
        mesh = bpy.data.meshes.new("OpponentUniform")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new("OpponentUniform", mesh)
        bpy.context.collection.objects.link(obj)
        for mat in self.materials:
            mesh.materials.append(mat)
        for face, mat in zip(mesh.polygons, self.material_ids):
            face.material_index = mat
            face.use_smooth = len(face.vertices) == 4
        groups = {}
        for vertex, weights in enumerate(self.weights):
            for bone, weight in weights.items():
                if bone not in groups:
                    if bone not in rig.data.bones:
                        raise ValueError(f"Missing rig bone {bone}")
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([vertex], weight, "REPLACE")
        obj.parent = rig
        modifier = obj.modifiers.new("Athlete rig", "ARMATURE")
        modifier.object = rig


def custom_player():
    reset()
    bpy.ops.import_scene.gltf(filepath=str(ASSETS / "UAL1_Standard.glb"))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    uniform = Uniform()
    uniform.torso()
    uniform.limbs(1, "l")
    uniform.limbs(-1, "r")
    uniform.helmet()
    uniform.mesh(rig)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name("OpponentUniform.blend")), compress=True)
    export("OpponentUniform.glb")


if __name__ == "__main__":
    if "--" in sys.argv:
        open_helmet(Path(sys.argv[sys.argv.index("--") + 1]))
    custom_player()
