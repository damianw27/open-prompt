#include <jni.h>
#include <string>

extern "C" {
#include "openprompt.h"
}

extern "C" JNIEXPORT jlong JNICALL Java_dev_openprompt_OpenPrompt_nativeCreate(JNIEnv *, jclass) {
    return reinterpret_cast<jlong>(op_engine_create(op_vfs_memory()));
}

extern "C" JNIEXPORT void JNICALL Java_dev_openprompt_OpenPrompt_nativeDestroy(JNIEnv *, jclass, jlong handle) {
    op_engine_destroy(reinterpret_cast<op_engine *>(handle));
}

extern "C" JNIEXPORT void JNICALL Java_dev_openprompt_OpenPrompt_nativeRegisterModule(
    JNIEnv *env, jclass, jlong handle, jstring path, jstring source) {
    const char *path_chars = env->GetStringUTFChars(path, nullptr);
    const char *source_chars = env->GetStringUTFChars(source, nullptr);
    const jsize source_len = env->GetStringUTFLength(source);
    op_engine_register_module(reinterpret_cast<op_engine *>(handle), path_chars, source_chars,
                              static_cast<size_t>(source_len));
    env->ReleaseStringUTFChars(path, path_chars);
    env->ReleaseStringUTFChars(source, source_chars);
}

extern "C" JNIEXPORT void JNICALL Java_dev_openprompt_OpenPrompt_nativeLoadString(
    JNIEnv *env, jclass, jlong handle, jstring source, jstring base_path) {
    const char *source_chars = env->GetStringUTFChars(source, nullptr);
    const char *base_chars = env->GetStringUTFChars(base_path, nullptr);
    const jsize source_len = env->GetStringUTFLength(source);
    op_engine_load_string(reinterpret_cast<op_engine *>(handle), source_chars,
                          static_cast<size_t>(source_len), base_chars);
    env->ReleaseStringUTFChars(source, source_chars);
    env->ReleaseStringUTFChars(base_path, base_chars);
}

extern "C" JNIEXPORT void JNICALL Java_dev_openprompt_OpenPrompt_nativeSetContextJson(
    JNIEnv *env, jclass, jlong handle, jstring json) {
    const char *json_chars = env->GetStringUTFChars(json, nullptr);
    const jsize json_len = env->GetStringUTFLength(json);
    op_engine_set_context_json(reinterpret_cast<op_engine *>(handle), json_chars, static_cast<size_t>(json_len));
    env->ReleaseStringUTFChars(json, json_chars);
}

extern "C" JNIEXPORT jstring JNICALL Java_dev_openprompt_OpenPrompt_nativeRender(JNIEnv *env, jclass, jlong handle) {
    char *output = nullptr;
    size_t output_len = 0;
    op_engine_render(reinterpret_cast<op_engine *>(handle), &output, &output_len);
    const std::string rendered(output, output_len);
    op_string_free(output);

    return env->NewStringUTF(rendered.c_str());
}
