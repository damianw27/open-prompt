#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace openprompt {

class Vfs {
public:
    virtual ~Vfs() = default;

    virtual bool read(std::string_view path, std::string &out) = 0;
    virtual bool write(std::string_view path, std::string_view source) = 0;
};

class MemoryVfs final : public Vfs {
public:
    bool read(std::string_view path, std::string &out) override;
    bool write(std::string_view path, std::string_view source) override;

private:
    std::unordered_map<std::string, std::string> files_;
};

class StdioVfs final : public Vfs {
public:
    explicit StdioVfs(std::vector<std::string> search_paths);

    bool read(std::string_view path, std::string &out) override;
    bool write(std::string_view path, std::string_view source) override;

private:
    std::vector<std::string> search_paths_;
    std::unordered_map<std::string, std::string> overlay_;
};

std::string normalizePath(std::string_view path);
std::string joinPath(std::string_view left, std::string_view right);
std::string basename(std::string_view path);

} // namespace openprompt
