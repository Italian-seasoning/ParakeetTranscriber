from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Resources" / "TileRenders"
OUTPUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.look = "AgX - Medium High Contrast"


def point_at(obj, target=(0, 0, 0)):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area_light(name, location, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    point_at(obj)


material = bpy.data.materials.new("Soft polymer")
material.use_nodes = True
shader = material.node_tree.nodes.get("Principled BSDF")
shader.inputs["Metallic"].default_value = 0.02
shader.inputs["Roughness"].default_value = 0.38
shader.inputs["Coat Weight"].default_value = 0.18
shader.inputs["Coat Roughness"].default_value = 0.32

area_light("Broad key", (-4.5, 4.5, 7.5), 620, 7.5, (1.0, 0.78, 0.92))
area_light("Cool fill", (4.0, -1.5, 6.0), 150, 8.5, (0.52, 0.62, 1.0))
area_light("Soft rim", (2.0, 5.0, 3.0), 190, 7.0, (0.9, 0.25, 1.0))

world = bpy.data.worlds.new("Dark studio")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.008, 0.014, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.1
scene.world = world

camera_data = bpy.data.cameras.new("Camera")
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0, 0, 10)
camera.data.type = "ORTHO"
point_at(camera)
scene.camera = camera


def make_tile(width, height, radius):
    bpy.ops.mesh.primitive_cube_add()
    obj = bpy.context.object
    obj.name = "Parakeet Tile"
    obj.dimensions = (width, height, radius * 2.35)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bevel = obj.modifiers.new("Deep soft bevel", "BEVEL")
    bevel.width = radius
    bevel.segments = 20
    bevel.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(material)
    return obj


tile = None


def render_tile(name, color, dimensions, resolution, radius):
    global tile
    if tile is not None:
        bpy.data.objects.remove(tile, do_unlink=True)
    tile = make_tile(*dimensions, radius=radius)
    bpy.context.view_layer.objects.active = tile

    shader.inputs["Base Color"].default_value = (*color, 1)
    camera.data.ortho_scale = dimensions[1] * 1.08
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUTPUT / f"tile-{name}.png")
    bpy.ops.render.render(write_still=True)


render_tile("graphite", (0.014, 0.018, 0.032), (5.25, 4.5), (1200, 1030), 0.62)
render_tile("magenta", (0.24, 0.008, 0.12), (5.0, 4.0), (640, 512), 0.72)
render_tile("violet", (0.025, 0.008, 0.22), (5.0, 4.0), (640, 512), 0.72)
