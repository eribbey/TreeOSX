#ifndef SwiftTreeCoreC_h
#define SwiftTreeCoreC_h

#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t name_offset;
    uint32_t name_length;
    uint8_t file_type;
    uint64_t logical_size;
    uint64_t allocated_size;
    uint64_t inode;
    uint8_t is_symlink;
} dv_entry;

int dv_read_dir(int dirfd,
                dv_entry *entries,
                int max_entries,
                char *namebuf,
                size_t namebuf_len,
                int *used_namebuf);

#ifdef __cplusplus
}
#endif

#endif /* SwiftTreeCoreC_h */
