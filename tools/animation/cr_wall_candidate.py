# Core Round Step 1E wall-run reach: build a CANDIDATE .blend with overridden wall-run parameters (preview only; the
# real source is built by cr_anim_build.py from the values committed in cr_anim_clips.py).
#   blender -b --factory-startup -P tools/animation/cr_wall_candidate.py -- <outdir> '<json>'
#   json: {"WALL_SHIFT": -0.3, "WALL_TILT": 4, "WALL_NECK": 1.6, "WALL_YAW": 30, "WALL_HIP_YAW": 20,
#          "WALL_ARM": [156, 5.4, -30, 61, 20]}
import json
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cr_anim_clips as C  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
for k, v in json.loads(args[1]).items():
    setattr(C, k, tuple(v) if isinstance(v, list) else v)
sys.argv = [sys.argv[0], "--", args[0]]
runpy.run_path(os.path.join(HERE, "cr_anim_build.py"), run_name="__main__")
