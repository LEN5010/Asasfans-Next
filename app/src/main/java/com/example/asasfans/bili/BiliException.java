package com.example.asasfans.bili;

import java.io.IOException;

public class BiliException extends IOException {
    private final int code;

    public BiliException(int code, String message) {
        super(message == null || message.isEmpty() ? "Bilibili API error: " + code : message);
        this.code = code;
    }

    public int getCode() {
        return code;
    }
}
