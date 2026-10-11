#!/usr/bin/env python
# This file is part of Presik POS.  The COPYRIGHT file at the top level of
# this repository contains the full copyright notices and license terms.
#from setuptools import setup
#-*- coding: utf-8 -*-
import os
import glob
import shutil
import sys
import py2exe

#from cx_Freeze import setup, Executable
from cx_Freeze import Executable
from distutils.core import setup

# Dependencies are automatically detected, but it might need fine tuning.
build_exe_options = {"packages": ["os"], "excludes": ["tkinter"]}

def read(fname):
    return open(os.path.join(os.path.dirname(sys.argv[0]), fname)).read()

args = {}
def files(pattern):
    return glob.glob(pattern)


def include_files(pattern, target_dir):
    return [
        (filename, os.path.join(target_dir, os.path.basename(filename)))
        for filename in glob.glob(pattern)
    ]


data_files = [
            ('app', files('*.ini') + files('app/*.css')),
            ('app/share', files('app/share/*.png') + files('app/share/*.jpg')
                + files('app/share/*.svg') + files('app/share/*.ico')),
            ('app/translations', files('app/translations/*.qm')),
            ('neox/css', files('neox/css/*.css')),
            ('neox/share', files('neox/share/*.png') + files('neox/share/*.svg')),
            ('neox/locale', files('neox/locale/*.qm')),
]

build_include_files = [
    *include_files('app/*.css', 'app'),
    *include_files('app/share/*.png', 'app/share'),
    *include_files('app/share/*.jpg', 'app/share'),
    *include_files('app/share/*.svg', 'app/share'),
    *include_files('app/share/*.ico', 'app/share'),
    *include_files('app/translations/*.qm', 'app/translations'),
    *include_files('neox/css/*.css', 'neox/css'),
    *include_files('neox/share/*.png', 'neox/share'),
    *include_files('neox/share/*.svg', 'neox/share'),
    *include_files('neox/locale/*.qm', 'neox/locale'),
    #(os.path.join('tryton', 'plugins'), 'plugins'),
    #(os.path.join(sys.prefix, 'share', 'glib-2.0', 'schemas'),
    #    os.path.join('share', 'glib-2.0', 'schemas')),
    #(os.path.join(sys.prefix, 'lib', 'gtk-3.0'),
    #    os.path.join('lib', 'gtk-3.0')),
    #(os.path.join(sys.prefix, 'lib', 'gdk-pixbuf-2.0'),
    #    os.path.join('lib', 'gdk-pixbuf-2.0')),
    #(os.path.join(sys.prefix, 'share', 'locale'),
    #    os.path.join('share', 'locale')),
    #(os.path.join(sys.prefix, 'share', 'icons', 'Adwaita'),
    #    os.path.join('share', 'icons', 'Adwaita')),
    #(os.path.join(sys.platform, 'gtk-3.0', 'gtk.immodules'),
    #    os.path.join('etc', 'gtk-3.0', 'gtk.immodules')),
    #(os.path.join(sys.platform, 'gtk-3.0', 'gdk-pixbuf.loaders'),
    #    os.path.join('etc', 'gtk-3.0', 'gdk-pixbuf.loaders')),
    ]

if os.name == 'posix':
    HOME_DIR = os.environ['HOME']
    default_dir = os.path.join(HOME_DIR, '.tryton')

    if not os.path.exists(default_dir):
        os.mkdir(default_dir, '0777')
    default_config = os.path.join(default_dir, 'config_pos.ini')

    if not os.path.exists(default_config):
        shutil.copyfile('config_pos.ini', default_config)
        path_inifile = os.path.join(default_dir, 'config_pos.ini')

base = None
if sys.platform == "win32":
    base = "Win32GUI"


executables = [
    Executable(script='pospro',
        initScript="c:\\apps\\presik_pos\\pospro",
        base=base,
        targetName="c:\\apps\\presik_pos\\build\\pospro.exe",
        icon=None,),
]


setup(name='pospro',
    version='5.0.0',
    description='Effica POS Client for Tryton',
    author='Josias Perez',
    author_email='jperez@apixela.net',
    url='www.effica.io',
    download_url="https://www.github.com",
    packages=[
            'app',
            'app/frontend',
            'app/share',
            'app/translations',
            'app/localization',
            'neox',
            'neox/commons',
            'neox/css',
            'neox/locale',
            'neox/share',
            ],
    data_files=data_files,
    scripts=['pospro'],
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Environment :: X11 Applications :: Qt',
        'Intended Audience :: End Users/Desktop',
        'License :: OSI Approved :: GNU General Public License (GPL)',
        'Operating System :: OS Independent',
        'Natural Language :: English',
        'Natural Language :: Spanish',
        'Programming Language :: Python',
        'Topic :: Office/Business',
    ],
    license='GPL',
    console='pospro.pyw',
    #install_requires=['PyQt5'],
    #executables = [Executable("pospro")],
    #executables=executables,
    #options = {"build_exe": build_exe_options},
    options={
        'build_exe': {
            'no_compress': True,
            'include_files': build_include_files,
            'silent': True,
            #'packages': ['PyQt5'],
            'include_msvcr': True,
            },
        'bdist_mac': {
            'iconfile': os.path.join(
                'tryton', 'data', 'pixmaps', 'tryton', 'tryton.icns'),
            'bundle_name': 'Tryton',
            }
        },
    #executables=[Executable(
    #        'pospro',
    #        base='Win32GUI' if sys.platform == 'win32' else None,
    #        icon=None,
    #        )]
)
