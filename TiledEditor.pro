#-------------------------------------------------
#
# Project created by QtCreator 2014-11-18T00:46:12
#
#-------------------------------------------------

QT       += core gui widgets

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = TiledEditor
TEMPLATE = app


SOURCES     += src/Main.cpp                     \
               src/FlickCharm.cpp               \
               src/CodeEditor.cpp               \
               src/CodeEditorCommands.cpp       \
               src/MDIChild.cpp                 \
               src/Util.cpp                     \
               src/libs/dropt/dropt.c           \
               src/libs/dropt/dropt_handlers.c  \
               src/libs/dropt/dropt_string.c    \
               src/libs/dropt/droptxx.cpp

HEADERS     += src/CodeEditor.h                 \
               src/FlickCharm.h                 \
               src/MDIChild.h                   \
               src/Util.h                       \
               src/libs/dropt/dropt.h           \
               src/libs/dropt/dropt_string.h    \
               src/libs/dropt/droptxx.hpp

RESOURCES   += mdi.qrc

