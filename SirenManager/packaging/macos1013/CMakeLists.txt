# Build Qt5 dédié au packaging macOS 10.13 (High Sierra, Intel x86_64).
# N'interfère PAS avec le build Qt6/WASM de la racine — c'est un projet séparé
# qui consomme l'arbre source versionné produit par prepare-qml.sh (build/stage).
cmake_minimum_required(VERSION 3.16)
project(SirenManagerLegacy VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Cible macOS 10.13 / Intel
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "" FORCE)
set(CMAKE_OSX_ARCHITECTURES "x86_64" CACHE STRING "" FORCE)

# Arbre source versionné Qt5 (généré par prepare-qml.sh)
set(STAGE "${CMAKE_CURRENT_SOURCE_DIR}/build/stage")

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Quick QuickControls2 WebSockets Network)

set(SOURCES
    ${STAGE}/main.cpp
    ${STAGE}/src/UdpController.cpp
    ${STAGE}/src/SshController.cpp
    ${STAGE}/src/PlaylistManager.cpp
    ${STAGE}/src/MachineManager.cpp
    ${STAGE}/src/Config/SirenConfig.cpp
    ${STAGE}/src/Models/PlaylistModel.cpp
)

qt5_add_resources(RESOURCES ${STAGE}/data.qrc)

add_executable(appSirenManager MACOSX_BUNDLE
    ${SOURCES}
    ${RESOURCES}
)

# main.cpp inclut "src/..." en chemin relatif → racine d'include = stage
target_include_directories(appSirenManager PRIVATE ${STAGE})

# Active le bloc QProcess qui lance le backend embarqué (voir main.cpp)
target_compile_definitions(appSirenManager PRIVATE BUNDLED_BACKEND)

target_link_libraries(appSirenManager PRIVATE
    Qt5::Core
    Qt5::Quick
    Qt5::QuickControls2
    Qt5::WebSockets
    Qt5::Network
)

set_target_properties(appSirenManager PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "SirenManager"
    MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.mecaviv.sirenmanager"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
)
