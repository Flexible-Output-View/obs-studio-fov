/**
 * @file integration_test.cpp
 * @author The FOV Team
 * @brief Implementation of the automated end-to-end integration test
 * @version 0.2
 * @date 2026-09-21
 */

#include "obs-data.h"
#include "obs.h"
#include "obs.hpp"
#include "obs-frontend-api.h"
#include "obs-module.h"
#include "util/platform.h"
#include <chrono>
#include <sstream>
#include <thread>
#include <vector>

bool find_media_file(char *out_path, size_t max_len)
{
	const char *relative_paths[] = {
		"plugins/flexible-output-view/integration_test/ressources/Big_Buck_Bunny_360_10s_20MB.mp4",
		"../plugins/flexible-output-view/integration_test/ressources/Big_Buck_Bunny_360_10s_20MB.mp4",
		"../../plugins/flexible-output-view/integration_test/ressources/Big_Buck_Bunny_360_10s_20MB.mp4",
		"../../../plugins/flexible-output-view/integration_test/ressources/Big_Buck_Bunny_360_10s_20MB.mp4",
		"../../../../plugins/flexible-output-view/integration_test/ressources/Big_Buck_Bunny_360_10s_20MB.mp4"};

	for (const char *rel : relative_paths) {
		os_get_abs_path(rel, out_path, max_len);
		if (os_file_exists(out_path)) {
			return true;
		}
	}
	return false;
}

void ensure_obs_video_audio_initialized()
{
	struct obs_video_info ovi = {};
	bool has_video = obs_get_video_info(&ovi);

	if (!has_video || ovi.base_width == 0 || ovi.base_height == 0 || ovi.fps_num == 0) {
		blog(LOG_INFO, "[FOV Test] Resetting OBS video parameters (1920x1080 @ 30fps)...");

		ovi.fps_num = 30;
		ovi.fps_den = 1;
		ovi.base_width = 1920;
		ovi.base_height = 1080;
		ovi.output_width = 1920;
		ovi.output_height = 1080;
		ovi.output_format = VIDEO_FORMAT_NV12;
		ovi.adapter = 0;
		ovi.gpu_conversion = true;
		ovi.colorspace = VIDEO_CS_709;
		ovi.range = VIDEO_RANGE_PARTIAL;

		int ret = obs_reset_video(&ovi);
		if (ret != OBS_VIDEO_SUCCESS) {
			blog(LOG_ERROR, "[FOV Test] Failed to reset video context: %d", ret);
		} else {
			blog(LOG_INFO, "[FOV Test] Successfully configured OBS video context (1920x1080 @ 30fps)");
		}
	} else {
		blog(LOG_INFO, "[FOV Test] Existing video context valid: %ux%u @ %u/%u fps", ovi.base_width,
		     ovi.base_height, ovi.fps_num, ovi.fps_den);
	}

	if (!obs_get_audio()) {
		struct obs_audio_info oai = {};
		oai.samples_per_sec = 48000;
		oai.speakers = SPEAKERS_STEREO;

		if (obs_reset_audio(&oai)) {
			blog(LOG_INFO, "[FOV Test] Successfully configured OBS audio context (48kHz Stereo)");
		} else {
			blog(LOG_ERROR, "[FOV Test] Failed to reset audio context");
		}
	}
}

void clear_scene_items(obs_scene_t *scene)
{
	if (!scene)
		return;

	std::vector<obs_sceneitem_t *> items;
	obs_scene_enum_items(
		scene,
		[](obs_scene_t *, obs_sceneitem_t *item, void *param) {
			auto *list = static_cast<std::vector<obs_sceneitem_t *> *>(param);
			list->push_back(item);
			return true;
		},
		&items);

	for (auto *item : items) {
		obs_sceneitem_remove(item);
	}
}

void create_source(OBSSourceAutoRelease &src, const char *path, const char *name)
{
	OBSDataAutoRelease data = obs_data_create();
	obs_data_set_string(data, "local_file", path);
	obs_data_set_bool(data, "looping", true);

	src = obs_source_create("ffmpeg_source", name, data, nullptr);
}

void configure_service(OBSServiceAutoRelease &service)
{
	OBSDataAutoRelease data = obs_data_create();
	OBSDataArrayAutoRelease videoArray = obs_data_array_create();
	OBSDataArrayAutoRelease audioArray = obs_data_array_create();

	obs_data_set_string(data, "server", "http://localhost:4000");
	obs_data_set_string(data, "key", "TestIntegration");

	for (int i = 1; i <= 2; i++) {
		std::stringstream is;
		is << "video" << i;
		OBSDataAutoRelease item = obs_data_create();
		obs_data_set_string(item, "name", is.str().c_str());
		obs_data_array_push_back(videoArray, item);
	}

	for (int i = 1; i <= 2; i++) {
		std::stringstream is;
		is << "video" << i;
		OBSDataAutoRelease item = obs_data_create();
		obs_data_set_string(item, "name", is.str().c_str());
		obs_data_array_push_back(audioArray, item);
	}

	obs_data_set_array(data, "videoTrackNames", videoArray);
	obs_data_set_array(data, "audioTrackNames", audioArray);

	service = obs_service_create("fov_service", "FOV Test Service", data, nullptr);
}

void start_fov()
{
	ensure_obs_video_audio_initialized();

	OBSSourceAutoRelease mSourceA;
	OBSSourceAutoRelease mSourceB;
	OBSServiceAutoRelease FOVService;
	char ABSPath[4090] = {0};

	bool found = find_media_file(ABSPath, sizeof(ABSPath));
	blog(LOG_INFO, "[FOV Test] Media file resolved to: %s (exists: %d)", ABSPath, found ? 1 : 0);

	OBSSourceAutoRelease current_scene_source = obs_frontend_get_current_scene();
	obs_scene_t *scene = obs_scene_from_source(current_scene_source);

	if (scene) {
		clear_scene_items(scene);
	} else {
		blog(LOG_ERROR, "[FOV Test] Could not retrieve active scene!");
	}

	create_source(mSourceA, ABSPath, "video1");
	create_source(mSourceB, ABSPath, "video2");

	if (scene) {
		if (mSourceA)
			obs_scene_add(scene, mSourceA);
		if (mSourceB)
			obs_scene_add(scene, mSourceB);
	}

	configure_service(FOVService);
	if (FOVService) {
		obs_frontend_set_streaming_service(FOVService);
        std::this_thread::sleep_for(std::chrono::seconds(20));
		obs_frontend_streaming_start();
		blog(LOG_INFO, "[FOV Test] Streaming started successfully.");
	} else {
		blog(LOG_ERROR, "[FOV Test] Failed to create FOV streaming service!");
        exit(42);
	}
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
