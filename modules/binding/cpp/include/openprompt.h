#ifndef OPENPROMPT_H_
#define OPENPROMPT_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    OP_OK = 0,
    OP_ERR_PARSE,
    OP_ERR_RENDER,
    OP_ERR_NOT_FOUND,
    OP_ERR_IO,
    OP_ERR_INVALID_ARG
} op_status;

typedef enum {
    OP_NULL = 0,
    OP_BOOL,
    OP_NUMBER,
    OP_STRING,
    OP_ARRAY,
    OP_MAP
} op_value_kind;

typedef struct op_engine op_engine;
typedef struct op_vfs op_vfs;
typedef struct op_value op_value;

typedef struct op_string_view {
    const char *data;
    size_t len;
} op_string_view;

op_vfs *op_vfs_stdio(const char *search_paths);
op_vfs *op_vfs_memory(void);
void op_vfs_destroy(op_vfs *vfs);

op_status op_vfs_register(op_vfs *vfs, const char *path, const char *source, size_t len);
op_status op_vfs_read(op_vfs *vfs, const char *path, char **out_data, size_t *out_len);

op_engine *op_engine_create(op_vfs *vfs);
void op_engine_destroy(op_engine *engine);

op_status op_engine_reset(op_engine *engine);
op_status op_engine_set_context_json(op_engine *engine, const char *json, size_t len);
op_status op_engine_register_module(op_engine *engine, const char *path, const char *source, size_t len);
op_status op_engine_load_file(op_engine *engine, const char *path);
op_status op_engine_load_string(op_engine *engine, const char *source, size_t len, const char *base_path);

op_status op_engine_render(op_engine *engine, char **out, size_t *out_len);
op_status op_engine_render_template(op_engine *engine, const char *name, char **out, size_t *out_len);

op_status op_engine_last_error(op_engine *engine, char **out, size_t *out_len);
void op_string_free(char *value);

op_value *op_value_null(void);
op_value *op_value_bool(int value);
op_value *op_value_number(double value);
op_value *op_value_string(const char *value, size_t len);
op_value *op_value_array(op_value **items, size_t count);
op_value *op_value_map(const char **keys, op_value **values, size_t count);
void op_value_release(op_value *value);

op_status op_engine_set_context_value(op_engine *engine, const char *root, op_value *value);

#ifdef __cplusplus
}
#endif

#endif
