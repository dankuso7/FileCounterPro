cmake_minimum_required(VERSION 3.16)
project(FileCounterProLinux VERSION 2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Source files
set(PROJECT_SOURCES
    src/main.cpp
    src/BackendInfo.cpp
    src/BackendInfo.h
    qml.qrc
)

qt_add_executable(FileCounterProLinux
    MANUAL_FINALIZATION
    ${PROJECT_SOURCES}
)

target_link_libraries(FileCounterProLinux PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

set_target_properties(FileCounterProLinux PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER my.example.com
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

# Deployment logic for AppImage usually handled via linuxdeployqt or macdeployqt.
