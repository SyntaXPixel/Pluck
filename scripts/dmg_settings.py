import os.path

# Variables can be injected via -D on the command line
_project_dir = defines.get('project_dir', os.getcwd())
_app_path = defines.get('app_path', os.path.join(_project_dir, 'build', 'Release', 'Pluck.app'))
_bg_path = defines.get('background_path', os.path.join(_project_dir, 'build', 'dmg-assets', 'dmg_background.png'))
_volume_icon = os.path.join(_project_dir, 'assest', 'Pluck.icns')

format = 'UDZO'
volume_name = 'Pluck'

# Volume icon shows on Desktop and in Finder sidebar
if os.path.exists(_volume_icon):
    icon = _volume_icon

files = [_app_path]

symlinks = {
    'Applications': '/Applications'
}

# Icon layout coordinates (center of window is 330)
# Hidden support files positioned far off-screen so they never visually overlap
icon_locations = {
    'Pluck.app': (180, 200),
    'Applications': (480, 200),
    '.background.tiff': (2000, 2000),
    '.VolumeIcon.icns': (2000, 2000)
}

background = _bg_path

# Window frame dimensions: 660 x (380 content + 28 title bar) = 660 x 408
window_rect = ((200, 120), (660, 408))
default_view = 'icon-view'
icon_size = 128
text_size = 12
show_status_bar = False
show_pathbar = False
show_toolbar = False
show_sidebar = False
show_tab_view = False
scroll_position = (0, 0)

hide = ['.background.tiff']
hide_extensions = ['Pluck.app']
