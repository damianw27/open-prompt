#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <new>
#include <vector>

namespace openprompt {

class Arena {
public:
    Arena() = default;

    Arena(const Arena &) = delete;
    Arena &operator=(const Arena &) = delete;

    ~Arena() {
        reset();
    }

    void reset() {
        for (auto *block : blocks_) {
            delete[] block;
        }

        blocks_.clear();
        current_ = nullptr;
        remaining_ = 0;
    }

    template <typename T, typename... Args>
    T *create(Args &&...args) {
        void *memory = allocate(sizeof(T), alignof(T));

        return new (memory) T(std::forward<Args>(args)...);
    }

    char *dup(std::string_view text) {
        if (text.empty()) {
            return const_cast<char *>("");
        }

        auto *out = static_cast<char *>(allocate(text.size() + 1, alignof(char)));
        std::memcpy(out, text.data(), text.size());
        out[text.size()] = '\0';

        return out;
    }

    void *allocate(std::size_t size, std::size_t alignment) {
        std::uintptr_t current_addr = reinterpret_cast<std::uintptr_t>(current_);
        std::uintptr_t aligned = (current_addr + alignment - 1) & ~(alignment - 1);
        std::size_t padding = aligned - current_addr;

        if (current_ == nullptr || padding + size > remaining_) {
            std::size_t block_size = size + alignment + 4096;
            auto *block = new char[block_size];
            blocks_.push_back(block);
            current_ = block;
            remaining_ = block_size;
            aligned = reinterpret_cast<std::uintptr_t>(current_);
            if (aligned % alignment != 0) {
                aligned = (aligned + alignment - 1) & ~(alignment - 1);
            }

            current_ = reinterpret_cast<char *>(aligned);
            remaining_ = block_size - (current_ - block);
        }

        void *result = current_;
        current_ += size;
        remaining_ -= size;

        return result;
    }

private:
    std::vector<char *> blocks_;
    char *current_ = nullptr;
    std::size_t remaining_ = 0;
};

} // namespace openprompt
