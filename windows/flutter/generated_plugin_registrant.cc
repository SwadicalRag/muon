//
//  Generated file. Do not edit.
//

#include "generated_plugin_registrant.h"

#include <file_selector_windows/file_selector_plugin.h>
#include <window_size/window_size_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FileSelectorPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorPlugin"));
  WindowSizePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowSizePlugin"));
}
