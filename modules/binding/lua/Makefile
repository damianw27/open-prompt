OPENPROMPT_ROOT := $(abspath ../cpp)
CORE_LIB := $(OPENPROMPT_ROOT)/build/libopenprompt_core.a
CXXFLAGS += -std=c++20 -I$(OPENPROMPT_ROOT)/include -I$(OPENPROMPT_ROOT)/../lsp/zig-pkg/tree_sitter-0.27.0-Tw2sR0TDCwBUIKjCd2avkJKfxXvSNZmdynJqiXMUYgAv/lib/include -I$(OPENPROMPT_ROOT)/../tree-sitter/src -I$(OPENPROMPT_ROOT)/../tree-sitter/src/tree_sitter
LDFLAGS += $(CORE_LIB) -lstdc++

.PHONY: all clean

all: openprompt.so

openprompt.so: src/openprompt.cpp
	$(CXX) $(CXXFLAGS) -fPIC -shared $< -o $@ $(LDFLAGS)

clean:
	rm -f openprompt.so
