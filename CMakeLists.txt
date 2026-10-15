cmake_minimum_required(VERSION 3.16)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "")
set(CMAKE_OSX_ARCHITECTURES x86_64 CACHE STRING "")
project(NinjaUpdater LANGUAGES OBJC)
find_package(MavericksShipyard REQUIRED)
include(Mavericks)
include(MavericksSparkle)
mavericks_resolve_version(NINJA_FULL_VERSION)
# spec: updater/ICON-CREDIT.txt -- the generic icon on purpose, with the reason and the exit
mavericks_add_updater_app(
  PRODUCT ninja
  PRODUCT_NAME "Mavericks ninja"
  VERSION "${NINJA_FULL_VERSION}"
  LOG_PREFIX "MavNinjaUpdater"
  CONFIRM_TITLE "Mavericks ninja updated"
  CONFIRM_BODY "ninja for Mavericks in /usr/local/mavergreen/ninja was updated."
  ALLOW_GENERIC
)
