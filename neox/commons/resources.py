import os
import sys
from pathlib import Path


def base_path():
    if hasattr(sys, '_MEIPASS'):
        return sys._MEIPASS
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return str(Path(__file__).resolve().parents[2])


def resource_path(*paths):
    return os.path.join(base_path(), *paths)
