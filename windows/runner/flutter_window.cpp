#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // Paint before engine/plugin initialization, rather than leaving the entire
  // application invisible until Flutter's first frame. No timer delays entry.
  startup_label_ = CreateWindow(
      L"STATIC", L"Asasfans Next",
      WS_CHILD | WS_VISIBLE | SS_OWNERDRAW,
      0, 0, frame.right, frame.bottom, GetHandle(), nullptr,
      GetModuleHandle(nullptr), nullptr);
  startup_font_ = CreateFont(
      -MulDiv(24, static_cast<int>(GetDpiForWindow(GetHandle())), 96),
      0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
  SendMessage(startup_label_, WM_SETFONT,
              reinterpret_cast<WPARAM>(startup_font_), TRUE);
  startup_icon_size_ =
      MulDiv(80, static_cast<int>(GetDpiForWindow(GetHandle())), 96);
  startup_icon_ = static_cast<HICON>(LoadImage(
      GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
      startup_icon_size_, startup_icon_size_, LR_DEFAULTCOLOR));
  Show();
  UpdateWindow(GetHandle());
  UpdateWindow(startup_label_);

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetWindowPos(startup_label_, HWND_TOP, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  // Same channel as macOS: "light" or "dark" as the app chose, anything
  // else hands the title bar back to the system.
  appearance_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "asasfans.next/window_appearance",
          &flutter::StandardMethodCodec::GetInstance());
  appearance_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* value = std::get_if<std::string>(call.arguments());
        if (call.method_name() != "set" || value == nullptr) {
          result->NotImplemented();
          return;
        }
        if (*value == "light") {
          dark_override_ = false;
        } else if (*value == "dark") {
          dark_override_ = true;
        } else {
          dark_override_.reset();
        }
        ApplyAppearance();
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    ClearStartupView();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. Ensure one is pending to remove the startup label even then.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  ClearStartupView();
  // The channel talks through the engine; release it first.
  appearance_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::ClearStartupView() {
  if (startup_label_) {
    DestroyWindow(startup_label_);
    startup_label_ = nullptr;
  }
  if (startup_font_) {
    DeleteObject(startup_font_);
    startup_font_ = nullptr;
  }
  if (startup_icon_) {
    DestroyIcon(startup_icon_);
    startup_icon_ = nullptr;
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_DRAWITEM && startup_label_ &&
      reinterpret_cast<DRAWITEMSTRUCT*>(lparam)->hwndItem == startup_label_) {
    const auto* item = reinterpret_cast<DRAWITEMSTRUCT*>(lparam);
    HDC dc = item->hDC;
    RECT bounds = item->rcItem;
    FillRect(dc, &bounds, GetSysColorBrush(COLOR_WINDOW));
    auto previous_font = SelectObject(dc, startup_font_);
    TEXTMETRIC metrics;
    GetTextMetrics(dc, &metrics);
    const int gap =
        MulDiv(24, static_cast<int>(GetDpiForWindow(GetHandle())), 96);
    const int top = (bounds.bottom - startup_icon_size_ - gap -
                     metrics.tmHeight) / 2;
    DrawIconEx(dc, (bounds.right - startup_icon_size_) / 2, top,
               startup_icon_, startup_icon_size_, startup_icon_size_,
               0, nullptr, DI_NORMAL);
    bounds.top = top + startup_icon_size_ + gap;
    bounds.bottom = bounds.top + metrics.tmHeight;
    SetTextColor(dc, GetSysColor(COLOR_WINDOWTEXT));
    SetBkMode(dc, TRANSPARENT);
    DrawText(dc, L"Asasfans Next", -1, &bounds, DT_CENTER | DT_SINGLELINE);
    SelectObject(dc, previous_font);
    return TRUE;
  }
  if (message == WM_SIZE && startup_label_) {
    RECT frame = GetClientArea();
    MoveWindow(startup_label_, 0, 0, frame.right, frame.bottom, TRUE);
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  const LRESULT result =
      Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  // A system theme change resets the frame to the system's; an explicit
  // choice in the app wins again.
  if (message == WM_DWMCOLORIZATIONCOLORCHANGED && dark_override_) {
    ApplyAppearance();
  }
  return result;
}

void FlutterWindow::ApplyAppearance() {
  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }
  if (!dark_override_) {
    UpdateTheme(window);
    return;
  }
  BOOL dark = *dark_override_ ? TRUE : FALSE;
  DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                        sizeof(dark));
}
