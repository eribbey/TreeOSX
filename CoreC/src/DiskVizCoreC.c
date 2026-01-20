#include "DiskVizCoreC.h"

#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#ifdef __APPLE__
#include <sys/attr.h>
#include <sys/dirent.h>
#include <sys/vnode.h>
#endif

#ifndef ATTR_CMN_NAME
#define ATTR_CMN_NAME 0x00000001
#endif

#ifndef ATTR_CMN_OBJTYPE
#define ATTR_CMN_OBJTYPE 0x00000008
#endif

#ifndef ATTR_CMN_FILEID
#define ATTR_CMN_FILEID 0x00001000
#endif

#ifndef ATTR_FILE_DATALENGTH
#define ATTR_FILE_DATALENGTH 0x00002000
#endif

#ifndef ATTR_FILE_ALLOCATEDSIZE
#define ATTR_FILE_ALLOCATEDSIZE 0x00004000
#endif

static int fill_entry_from_stat(const struct stat *st, dv_entry *entry) {
    entry->logical_size = (uint64_t)st->st_size;
    entry->allocated_size = (uint64_t)st->st_blocks * 512ULL;
    entry->inode = (uint64_t)st->st_ino;
    entry->is_symlink = S_ISLNK(st->st_mode) ? 1 : 0;
    if (S_ISDIR(st->st_mode)) {
        entry->file_type = DT_DIR;
    } else if (S_ISREG(st->st_mode)) {
        entry->file_type = DT_REG;
    } else if (S_ISLNK(st->st_mode)) {
        entry->file_type = DT_LNK;
    } else {
        entry->file_type = DT_UNKNOWN;
    }
    return 0;
}

static int dv_read_dir_readdir(int dirfd,
                               dv_entry *entries,
                               int max_entries,
                               char *namebuf,
                               size_t namebuf_len,
                               int *used_namebuf) {
    int dupfd = dup(dirfd);
    if (dupfd == -1) {
        return -1;
    }
    DIR *dir = fdopendir(dupfd);
    if (!dir) {
        close(dupfd);
        return -1;
    }

    int count = 0;
    size_t name_offset = 0;
    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0) {
            continue;
        }
        size_t name_len = strlen(ent->d_name);
        if (count >= max_entries) {
            break;
        }
        if (name_offset + name_len + 1 > namebuf_len) {
            break;
        }

        dv_entry *entry = &entries[count];
        entry->name_offset = (uint32_t)name_offset;
        entry->name_length = (uint32_t)name_len;
        memcpy(namebuf + name_offset, ent->d_name, name_len + 1);
        name_offset += name_len + 1;

        struct stat st;
        if (fstatat(dirfd, ent->d_name, &st, AT_SYMLINK_NOFOLLOW) == 0) {
            fill_entry_from_stat(&st, entry);
        } else {
            entry->logical_size = 0;
            entry->allocated_size = 0;
            entry->inode = 0;
            entry->is_symlink = 0;
            entry->file_type = ent->d_type;
        }
        count++;
    }

    closedir(dir);
    *used_namebuf = -1;
    return count;
}

int dv_read_dir(int dirfd,
                dv_entry *entries,
                int max_entries,
                char *namebuf,
                size_t namebuf_len,
                int *used_namebuf) {
#ifdef __APPLE__
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_NAME | ATTR_CMN_OBJTYPE | ATTR_CMN_FILEID;
    attrs.fileattr = ATTR_FILE_DATALENGTH | ATTR_FILE_ALLOCATEDSIZE;

    ssize_t buf_size = 64 * 1024;
    char buffer[64 * 1024];
    int count = getattrlistbulk(dirfd, &attrs, buffer, buf_size, 0);
    if (count <= 0) {
        if (errno == ENOTSUP || errno == EINVAL) {
            return dv_read_dir_readdir(dirfd, entries, max_entries, namebuf, namebuf_len, used_namebuf);
        }
        return -1;
    }

    size_t name_offset = 0;
    int entry_count = 0;
    char *cursor = buffer;
    for (int i = 0; i < count; i++) {
        if (entry_count >= max_entries) {
            break;
        }
        uint32_t record_length = *(uint32_t *)cursor;
        char *record = cursor + sizeof(uint32_t);

        char *name = NULL;
        uint32_t name_len = 0;
        uint32_t objtype = 0;
        uint64_t fileid = 0;
        uint64_t data_length = 0;
        uint64_t allocated_size = 0;

        attrreference_t *name_ref = NULL;
        if (attrs.commonattr & ATTR_CMN_NAME) {
            name_ref = (attrreference_t *)record;
            record += sizeof(attrreference_t);
        }
        if (attrs.commonattr & ATTR_CMN_OBJTYPE) {
            objtype = *(uint32_t *)record;
            record += sizeof(uint32_t);
        }
        if (attrs.commonattr & ATTR_CMN_FILEID) {
            fileid = *(uint64_t *)record;
            record += sizeof(uint64_t);
        }
        if (attrs.fileattr & ATTR_FILE_DATALENGTH) {
            data_length = *(uint64_t *)record;
            record += sizeof(uint64_t);
        }
        if (attrs.fileattr & ATTR_FILE_ALLOCATEDSIZE) {
            allocated_size = *(uint64_t *)record;
            record += sizeof(uint64_t);
        }

        if (name_ref) {
            name = (char *)record + name_ref->attr_dataoffset;
            name_len = name_ref->attr_length;
        }

        if (!name || name_len == 0) {
            cursor += record_length;
            continue;
        }

        size_t copy_len = name_len;
        if (copy_len > 0 && name[copy_len - 1] == '\0') {
            copy_len -= 1;
        }
        if (name_offset + copy_len + 1 > namebuf_len) {
            break;
        }

        dv_entry *entry = &entries[entry_count];
        entry->name_offset = (uint32_t)name_offset;
        entry->name_length = (uint32_t)copy_len;
        memcpy(namebuf + name_offset, name, copy_len);
        namebuf[name_offset + copy_len] = '\0';
        name_offset += copy_len + 1;

        entry->logical_size = data_length;
        entry->allocated_size = allocated_size;
        entry->inode = fileid;
        entry->is_symlink = 0;
        switch (objtype) {
            case VDIR:
                entry->file_type = DT_DIR;
                break;
            case VREG:
                entry->file_type = DT_REG;
                break;
            case VLNK:
                entry->file_type = DT_LNK;
                entry->is_symlink = 1;
                break;
            default:
                entry->file_type = DT_UNKNOWN;
                break;
        }

        entry_count++;
        cursor += record_length;
    }

    *used_namebuf = (int)name_offset;
    return entry_count;
#else
    return dv_read_dir_readdir(dirfd, entries, max_entries, namebuf, namebuf_len, used_namebuf);
#endif
}
