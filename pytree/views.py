# -*- coding: utf-8 -*-

import re
import os
import subprocess
import yaml
from yaml import FullLoader

from flask import jsonify, request, render_template, abort
from flask_cors import cross_origin

from pytree import app

COORD_REGEX = re.compile(r'\{([0-9]+(\.[0-9]+)?), ?([0-9]+(\.[0-9]+)?)\}, ?(\{([0-9]+(\.[0-9]+)?), ?([0-9]+(\.[0-9]+)?)\}(, ?)?)+')

pytree_config = {}
for filename in ['/etc/pytree/config.yaml', '/etc/pytree/config.yml', '/app/pytree.yaml', '/app/pytree.yml']:
    if os.path.isfile(filename):
        with open(filename, encoding='utf-8') as f:
            pytree_config = yaml.load(f, Loader=FullLoader)
        break

def _render_home(base_url: str) -> str:
    point_clouds = pytree_config['vars'].get('pointclouds', {})
    default_point_cloud = list(point_clouds.keys())[0] if len(point_clouds) > 0 else ''
    return render_template(
        'home.html',
        default_point_cloud=pytree_config['vars'].get('default_point_cloud', default_point_cloud),
        default_min_lod=pytree_config['vars'].get('default_min_lod', 0),
        default_max_lod=pytree_config['vars'].get('default_max_lod', 6),
        default_width=pytree_config['vars'].get('default_width', 6),
        default_coordinates=pytree_config['vars'].get('default_coordinates', '{2558950,1206060},{2561250,1206660}'),
        base_url=base_url
    )

@app.route('/')
def home():
    return _render_home('profile/')

@app.route('/profile/')
def home_bis():
    return _render_home('')


@app.route("/profile/get")
@cross_origin()
def get_profile():
    app.logger.debug('Pytree config:\n%s', pytree_config)

    cpotree = pytree_config['vars'].get('cpotree_executable', 'extract_profile')
    point_clouds = pytree_config['vars'].get('pointclouds', {})
    app.logger.debug('Request args:\n%s', request.args)

    coordinates = request.args.get('coordinates')
    if not COORD_REGEX.match(coordinates):
        abort(400, 'coordinates parameter is malformed')

    try:
        max_lod = int(request.args.get('maxLOD'))
    except ValueError:
        abort(400, 'maxLOD is not an integer')

    try:
        min_lod = int(request.args.get('minLOD'))
    except ValueError:
        abort(400, 'minLOD is not an integer')

    try:
        width = float(request.args.get('width'))
    except ValueError:
        abort(400, 'width is not a float')

    point_cloud = request.args.get('pointCloud')

    if point_cloud not in point_clouds:
        abort(400, 'The referenced point cloud is unknown.')

    potree_uri = point_clouds[point_cloud]

    cmd = [cpotree, potree_uri, "--stdout",
        "-o", 'stdout',
        "--coordinates", coordinates,
        "--width", str(width),
        "--min-level", str(min_lod),
        "--max-level", str(max_lod)
    ]

    app.logger.debug('Subprocess command:\n%s', cmd)

    p = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
    return p.stdout


@app.route("/profile/config")
@cross_origin()
def profile_config_gmf2():

    config = pytree_config['vars'].copy()

    if 'cpotree_executable' in config:
        config.pop('cpotree_executable')

    config['pointclouds'] = list(config.get('pointclouds', {}).keys())

    return jsonify(config)
