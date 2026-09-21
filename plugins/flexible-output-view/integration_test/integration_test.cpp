/**
 * @file integration_test.cpp
 * @author The FOV Team
 * @brief Implementation of the automated end to end integration test
 * @version 0.1
 * @date 2026-09-18
 */

#include <chrono>
#include <obs-frontend-api.h>
#include <obs-module.h>
#include <callback/signal.h>
#include <thread>

void start_fov()
{
    std::this_thread::sleep_for(std::chrono::seconds(60));
    obs_frontend_streaming_start();
}


void handle_frontend_event(enum obs_frontend_event event, void *)
{
    if (event == OBS_FRONTEND_EVENT_FINISHED_LOADING) {
        start_fov();
    }
}


extern "C" {

OBS_DECLARE_MODULE();

MODULE_EXPORT const char *obs_module_description(void)
{
	return "The flexible output view integration test plugin";
}


bool obs_module_load(void)
{
    obs_frontend_add_event_callback(handle_frontend_event, nullptr);
	return true;
}


void obs_module_unload(void)
{
	return;
}
}
