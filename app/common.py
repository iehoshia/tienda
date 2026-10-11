from PIL import Image, ImageDraw
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QApplication
from io import BytesIO
from slugify import slugify

import os
import ctypes

from neox.commons.resources import resource_path

current_dir = resource_path('app')
_WINDOW_ICON_HANDLES = {}

def get_effica_icon():
    """Return the application icon used by every Effica window."""
    icon_path = os.path.join(current_dir, 'share', 'pos-icon-01.ico')
    if not os.path.exists(icon_path):
        icon_path = os.path.join(current_dir, 'share', 'pos-icon-01.png')
    return QIcon(icon_path)


def apply_effica_window_icon(window):
    """Apply Effica's icon to Qt and to the native Windows taskbar button."""
    icon = get_effica_icon()
    window.setWindowIcon(icon)
    application = QApplication.instance()
    if application is not None:
        application.setWindowIcon(icon)

    if os.name == 'nt':
        try:
            hwnd = int(window.winId())
            icon_path = os.path.join(current_dir, 'share', 'pos-icon-01.ico')
            load_image = ctypes.windll.user32.LoadImageW
            load_image.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p,
                ctypes.c_uint, ctypes.c_int, ctypes.c_int, ctypes.c_uint]
            load_image.restype = ctypes.c_void_p
            flags = 0x00000010  # LR_LOADFROMFILE
            image_type = 1       # IMAGE_ICON
            small = load_image(None, icon_path, image_type, 16, 16, flags)
            big = load_image(None, icon_path, image_type, 32, 32, flags)
            send_message = ctypes.windll.user32.SendMessageW
            send_message.argtypes = [ctypes.c_void_p, ctypes.c_uint,
                ctypes.c_size_t, ctypes.c_void_p]
            send_message.restype = ctypes.c_void_p
            send_message(hwnd, 0x0080, 0, small)  # WM_SETICON / ICON_SMALL
            send_message(hwnd, 0x0080, 1, big)    # WM_SETICON / ICON_BIG
            _WINDOW_ICON_HANDLES[hwnd] = (small, big)
        except Exception:
            pass
    return icon

def get_svg_icon(name):
    file_icon = name if name else 'fork'
    path_icon = os.path.join(current_dir, 'share', file_icon + '.svg')
    _icon = QIcon(path_icon)
    return _icon

def get_png_icon(name):
    name = slugify(name)

    file_icon = name if name else 'fork'
    path_icon = os.path.join(current_dir, 'tmp', file_icon + '.PNG')
    _icon = QIcon(path_icon)
    return _icon

def get_local_png_icon(name):
    name = slugify(name)

    file_icon = name if name else 'fork'
    path_icon = os.path.join(current_dir, 'share', file_icon + '.PNG') or \
        os.path.join(current_dir, 'share', file_icon + '.png') 
    _icon = QIcon(path_icon)
    return _icon

def create_icon_file(name, data):
    try:
        name = slugify(name)
        file_icon = name if name else 'fork'
        path_icon = os.path.join(current_dir, 'tmp', file_icon + '.png')
        image_data = BytesIO(data)
        image = Image.open(image_data)
        image.save(path_icon, 'PNG')
    except:
        pass
