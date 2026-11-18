// pmem.h —— NPC 的存储器模型
//
// 128 MiB，基址 0x80000000。绝对地址按 addr - BASE 映射到数组下标；
// 越界由 has_byte/has_word 拒绝，不做取模回绕。
// 镜像由 load() 读入偏移 0，对应基址处。

#ifndef MINIRV_PMEM_H
#define MINIRV_PMEM_H

#include <cstdint>
#include <cstdio>
#include <cstring>

struct Pmem {
    // 与 AM 的 _pmem_start、PMEM_SIZE 保持一致
    static constexpr uint32_t BASE = 0x80000000u;
    static constexpr uint32_t SIZE = 128u * 1024 * 1024;

    uint8_t mem[SIZE];

    void reset(void)
    {
        std::memset(mem, 0, sizeof(mem));
    }

    bool load(const char *path)
    {
        std::FILE *fp = std::fopen(path, "rb");
        if (fp == nullptr) {
            std::fprintf(stderr, "pmem: cannot open %s\n", path);
            return false;
        }

        size_t n = std::fread(mem, 1, SIZE, fp);
        bool bad = std::ferror(fp) != 0;
        std::fclose(fp);
        if (bad) {
            std::fprintf(stderr, "pmem: read error on %s\n", path);
            return false;
        }
        std::printf("pmem: loaded %zu bytes from %s\n", n, path);
        return true;
    }

    // 范围检查取代取模回绕，避免越界地址被别名进数组
    bool has_word(uint32_t addr) const
    {
        return addr >= BASE && addr - BASE <= SIZE - 4;
    }

    bool has_byte(uint32_t addr) const
    {
        return addr >= BASE && addr - BASE < SIZE;
    }

    uint8_t read8(uint32_t addr) const
    {
        return mem[addr - BASE];
    }

    // 对齐到 4 字节，按小端拼装
    uint32_t read32(uint32_t addr) const
    {
        uint32_t off = (addr - BASE) & ~3u;
        uint32_t value = 0;
        for (int i = 3; i >= 0; i--)
            value = (value << 8) | mem[off + static_cast<uint32_t>(i)];
        return value;
    }

    // be 的第 i 位对应 off+i 字节
    void write(uint32_t addr, uint32_t data, uint8_t be)
    {
        uint32_t off = (addr - BASE) & ~3u;
        for (uint32_t i = 0; i < 4; i++) {
            if (be & (1u << i))
                mem[off + i] = static_cast<uint8_t>(data >> (8 * i));
        }
    }
};

#endif
