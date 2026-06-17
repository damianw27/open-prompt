#include "vfs.hpp"

#include <fstream>
#include <sstream>

namespace openprompt {

std::string normalizePath(std::string_view path) {
    std::string copy(path);

    for (char &byte : copy) {
        if (byte == '\\') {
            byte = '/';
        }
    }

    return copy;
}

std::string joinPath(std::string_view left, std::string_view right) {
    if (left.empty()) {
        return std::string(right);
    }

    if (right.empty()) {
        return std::string(left);
    }

    if (left.back() == '/') {
        return std::string(left) + std::string(right);
    }

    return std::string(left) + "/" + std::string(right);
}

std::string basename(std::string_view path) {
    const auto slash = path.find_last_of('/');

    if (slash == std::string_view::npos) {
        return std::string(path);
    }

    return std::string(path.substr(slash + 1));
}

bool MemoryVfs::read(std::string_view path, std::string &out) {
    const auto key = normalizePath(path);
    auto iterator = files_.find(key);

    if (iterator == files_.end()) {
        return false;
    }

    out = iterator->second;

    return true;
}

bool MemoryVfs::write(std::string_view path, std::string_view source) {
    files_[normalizePath(path)] = std::string(source);

    return true;
}

StdioVfs::StdioVfs(std::vector<std::string> search_paths)
    : search_paths_(std::move(search_paths)) {}

bool StdioVfs::read(std::string_view path, std::string &out) {
    const auto normalized = normalizePath(path);
    auto overlay_iterator = overlay_.find(normalized);

    if (overlay_iterator != overlay_.end()) {
        out = overlay_iterator->second;

        return true;
    }

    std::vector<std::string> candidates;
    candidates.push_back(normalized);

    for (const auto &search_path : search_paths_) {
        candidates.push_back(joinPath(search_path, normalized));
    }

    for (const auto &candidate : candidates) {
        std::ifstream stream(candidate, std::ios::binary);

        if (!stream) {
            continue;
        }

        std::ostringstream buffer;
        buffer << stream.rdbuf();
        out = buffer.str();

        return true;
    }

    return false;
}

bool StdioVfs::write(std::string_view path, std::string_view source) {
    overlay_[normalizePath(path)] = std::string(source);

    return true;
}

} // namespace openprompt
