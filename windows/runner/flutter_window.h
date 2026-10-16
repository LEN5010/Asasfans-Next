#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>

#include "win32_window.h"

// Hosts Flutter, showing the app name while the engine starts.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  HWND startup_label_ = nullptr;
  HFONT startup_font_ = nullptr;

  // The title bar is native: the app's light or dark choice reaches it
  // through this channel. No value means the system decides.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      appearance_channel_;
  std::optional<bool> dark_override_;

  // Applies the app's choice to the frame, or the system theme.
  void ApplyAppearance();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
