cmake_minimum_required(VERSION 3.28)

add_library(fov-integration-test MODULE)
add_library(OBS::fov-integration-test ALIAS fov-integration-test)

target_sources(fov-integration-test PRIVATE
    integration_test.cpp
)

target_link_libraries(fov-integration-test PRIVATE OBS::libobs $<$<PLATFORM_ID:Windows>:OBS::w32-pthreads> OBS::frontend-api)

set_target_properties_obs(fov-integration-test PROPERTIES FOLDER plugins PREFIX "")
