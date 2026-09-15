cmake_minimum_required(VERSION 3.28)

add_library(flexible-output-view MODULE)
add_library(OBS::flexible-output-view ALIAS flexible-output-view)

if(ENABLE_FOV_DEBUG_INGEST)
    target_compile_definitions(flexible-output-view PUBLIC DEBUG_INGEST_STREAM)
endif()

target_sources(flexible-output-view PRIVATE
    fov.cpp
    moq/fov-moq-output.cpp
    moq/fov-moq.cpp
    moq/moq-settings.cpp
    service/fov_service.cpp
    service/curl_wrapper.cpp
)

target_include_directories(flexible-output-view PRIVATE
    ${OBS_FRONTEND_API_INCLUDE_DIRS}
    ./service
)

if(MSVC)
    set_property(TARGET flexible-output-view APPEND_STRING PROPERTY LINK_FLAGS_DEBUG " /NODEFAULTLIB:MSVCRT")
endif()

target_link_libraries(flexible-output-view PRIVATE OBS::libobs $<$<PLATFORM_ID:Windows>:OBS::w32-pthreads> OBS::frontend-api CURL::libcurl moq)

set_target_properties_obs(flexible-output-view PROPERTIES FOLDER plugins PREFIX "")