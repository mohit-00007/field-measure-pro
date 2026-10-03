cmake_minimum_required(VERSION 3.14)
project(field_measure_pro LANGUAGES CXX)

set(BINARY_NAME "field_measure_pro")

cmake_policy(SET CMP0079 NEW)

# Flutter Windows configuration
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Application build settings
add_subdirectory("${FLUTTER_MANAGED_DIR}")
add_subdirectory("runner")

# Target executable configuration
add_executable(${BINARY_NAME} WIN32
  "runner/main.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

apply_standard_settings(${BINARY_NAME})
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
