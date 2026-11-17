// pmem.h —— 处理器之外的存储器，用 C++ 实现
//
// 容量 64 KiB，按字节寻址，小端。与 minirvEMU 的 cpu.mem 同尺寸，
// 复位后全零，镜像从地址 0 开始放置。
//
// 读写都按对齐后的字进行：read32 返回包含 addr 的那个 32 位字，
// lbu 要的字节由处理器用 addr[1:0] 自己选。write 按字节使能掩码，
// 只有 be 为 1 的字节被改写。

#ifndef MINIRV_PMEM_H
#define MINIRV_PMEM_H

#include <cstdint>
#include <cstdio>
#include <cstring>

struct Pmem {
    static constexpr uint32_t SIZE = 1u << 16;

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

    bool has_word(uint32_t addr) const
    {
        return (addr & (SIZE - 1)) == addr && addr <= SIZE - 4;
    }

    bool has_byte(uint32_t addr) const
    {
        return (addr & (SIZE - 1)) == addr;
    }

    uint8_t read8(uint32_t addr) const
    {
        return mem[addr & (SIZE - 1)];
    }

    uint32_t read32(uint32_t addr) const
    {
        uint32_t base = addr & (SIZE - 1) & ~3u;
        uint32_t value = 0;
        for (int i = 3; i >= 0; i--)
            value = (value << 8) | mem[base + static_cast<uint32_t>(i)];
        return value;
    }

    void write(uint32_t addr, uint32_t data, uint8_t be)
    {
        uint32_t base = addr & (SIZE - 1) & ~3u;
        for (uint32_t i = 0; i < 4; i++) {
            if (be & (1u << i))
                mem[base + i] = static_cast<uint8_t>(data >> (8 * i));
        }
    }
};

#endif
