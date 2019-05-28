cmake_minimum_required(VERSION 3.0)

set(CMAKE_CXX_STANDARD 11)
set(QT_MIN_VERSION 5.4.0)

include_directories(${Qt5Widgets_INCLUDE_DIRS})
add_definitions(${Qt5Widgets_DEFINITIONS})
add_definitions(${Qt5Widgets_COMPILE_DEFINITIONS})


set(PROJECT "TiledEditor")
project(${PROJECT} VERSION 0.0.1)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

# message("CMAKE_SYSTEM_NAME: ${CMAKE_SYSTEM_NAME}")

find_package(Qt5 ${QT_MIN_VERSION} CONFIG REQUIRED
  Core
  Gui
  Widgets
)

# find_package(PkgConfig REQUIRED)
# pkg_check_modules(hunspell hunspell)
# if(hunspell_FOUND)
#   add_definitions(-DHUNSPELL_ENABLE)
#   message("+ hunspell support")
# endif()

# find_path(ASPELL_INLCUDES aspell.h "/usr/include/" "/usr/local/")
# if(ASPELL_INLCUDES)
#   add_definitions(-DASPELL_ENABLE)
#   target_link_libraries(${PROJECT} libaspell.so)
#   message("+ aspell support")
# endif()

# find_package(Qt5PrintSupport)
# if (Qt5PrintSupport_FOUND)
#   Message ("+ printer support")
#   add_definitions(-DPRINTER_ENABLE)
#   target_link_libraries(${PROJECT} Qt5::PrintSupport)
# endif()

if(BUILD_TESTING)
  find_package(Qt5Test ${QT_MIN_VERSION} CONFIG REQUIRED)
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${Qt5Widgets_EXECUTABLE_COMPILE_FLAGS}")


set(PROJECT_SRCS
  src/Main.cpp
  src/FlickCharm.cpp
  src/CodeEditor.cpp
  src/CodeEditorCommands.cpp
  src/MDIChild.cpp
  src/Util.cpp
  src/libs/dropt/dropt.c
  src/libs/dropt/dropt_handlers.c
  src/libs/dropt/dropt_string.c
  src/libs/dropt/droptxx.cpp
)

qt5_add_resources(QT_RESOURCES resources/mdi.qrc)

add_executable(${PROJECT}
  ${PROJECT_SRCS}
  ${QT_RESOURCES}
)

target_link_libraries(${PROJECT}
  Qt5::Core
  Qt5::Gui
  Qt5::Widgets
)

set_property(SOURCE qrc_mdi.cpp PROPERTY SKIP_AUTOGEN ON)
