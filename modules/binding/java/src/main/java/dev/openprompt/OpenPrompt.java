package dev.openprompt;

public final class OpenPrompt {
    static {
        System.loadLibrary("openprompt");
    }

    private long engineHandle;

    public OpenPrompt() {
        engineHandle = nativeCreate();
    }

    public void registerModule(String path, String source) {
        nativeRegisterModule(engineHandle, path, source);
    }

    public void loadString(String source, String basePath) {
        nativeLoadString(engineHandle, source, basePath);
    }

    public void setContextJson(String json) {
        nativeSetContextJson(engineHandle, json);
    }

    public String render() {
        return nativeRender(engineHandle);
    }

    public void close() {
        if (engineHandle != 0) {
            nativeDestroy(engineHandle);
            engineHandle = 0;
        }
    }

    private static native long nativeCreate();
    private static native void nativeDestroy(long handle);
    private static native void nativeRegisterModule(long handle, String path, String source);
    private static native void nativeLoadString(long handle, String source, String basePath);
    private static native void nativeSetContextJson(long handle, String json);
    private static native String nativeRender(long handle);
}
