#include <stdio.h>
#include "tree.h"

#define NIL -1<<31
/*
   serialization format:
   binary array, breath first format.
   |special_tag|root|root_left|root_right|...|


*/

int tree_serialize(node_t *root, int fd)
{
    fseek(st, sizeof(uint32_t), SEEK_SET);
    uint32_t max_value = serialize_subtree(root, fd, 1);
    fseek(st, 0, SEEK_SET);
    dprintf(fd, "1", 1);
    fwrite(fd, sizeof(uint32_t), &max_value);
    fdatasync(fd);
    fclose(fd);
    return 0;
}

/*     1
      / \
     2   3
    / \ / \
   4  5 6  7
   ... \
       11
 */
int serialize_subtree(node_t * root, int fd, uint32_t pos)
{
    uint32_t ldepth=0, rdepth=0;
    fseek(fd, pos, SEEK_SET);
    if(root->value == NULL) {
        dprintf(fd, " ");
        //write(fd, NIL, sizeof(int32_t);
        return 0;
    }

    dprintf(fd, "%d",root->value);
    //write(fd, *(root->value), sizeof(int32_t));

    if(root->left != NULL)
        ldepth = serialize_subtree(root->left, fd, pos*2);
    if(root->right != NULL)
        rdepth = serialize_subtree(root->right, fd, (pos*2)+1);
    // if any child wrote, return biggest value
    if( ldepth > pos || rdepth > pos)
        return ldepth > rdepth ? ldepth : rdepth;
    return pos;
}
// [x 1 2  4 5
/*     1
      / \
     2   3
    / \ / \
   4  5 6  7
   ...

      4
    /  \
   2    7
  / \  / \
 1  3  6  8
 */
node_t * tree_deserialize(int fd)
{
    struct stat sta;
    uint32_t max_pos;
    uint8_t *buff;
    node_t *root;

    fstat(fd, &sta);

    buff = calloc(sta.st_size, 1);
    fread(fd, sta.st_size, buff);

    return read_tree_node(1, buf + sizeof(uint32_t));
}

node_t * read_tree_node(uint32_t pos, uint8_t *buf)
{
    node_t *node = NULL;
    int32_t *val = (int32_t *) buf[pos * sizeof(int32_t)];
    if( *val == NIL)
        return NULL;
    node = calloc(sizeof(node_t), 1);
    node->value = calloc(sizeof(int32_t), 1);
    memcpy(node->value, val, sizeof(int32_t));


    node->right = read_tree_node( pos*2, buf);
    node->left = read_tree_node(pos*2 +1, buf);

    return node;
}




