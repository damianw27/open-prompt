{
  "targets": [
    {
      "target_name": "openprompt_native",
      "sources": ["native/binding.cc"],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")",
        "../cpp/include"
      ],
      "libraries": [
        "<(module_root_dir)/../cpp/build/libopenprompt_core.a",
        "-lstdc++"
      ],
      "library_dirs": [
        "<(module_root_dir)/../cpp/build"
      ],
      "cflags_cc": ["-std=c++20", "-fexceptions"]
    }
  ]
}
