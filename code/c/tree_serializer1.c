#include <stdio.h>

struct tree_node {
    struct tree_node *left;
    struct tree_node *right;
    value_t *value;
} node_t;

/*
   serialization format:
   binary array, breath first format.
   |special_tag|root|root_left|root_right|...|


*/

int serialize_tree(node_t *root, int fd)
{
    fseek(st, sizeof(unsigned), SEEK_SET);
    unsigned max_value = serialize_subtree(root, fd, 1);
    fseek(st, 0, SEEK_SET);
    fwrite(fd, sizeof(unsigned), &max_value);
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
#define NIL -1<<31
int serialize_subtree(node_t * root, int fd, unsigned pos)
{
    unsigned ldepth=0, rdepth=0;
    if(root->value == NULL) {
        write(fd, NIL, sizeof(value_t);
        return 0;
    }
    fseek(fd, pos, SEEK_SET);
    write(fd, *(root->value), sizeof(value_t));
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
node_t * deserialize_subtree(int fd)
{
    struct stat sta;
    unsigned max_pos;
    char *buff;
    node_t *root;

    fstat(fd, &sta);

    buff = calloc(sta.st_size, 1);
    fread(fd, sta.st_size, buff);

    return read_tree_node(1, buf + sizeof(unsigned));
}

node_t * read_tree_node(unsigned pos, char *buf)
{
    node_t *node = NULL;
    value_t *val = (value_t *) buf[pos * sizeof(value_t)];
    if( *val == NIL)
        return NULL;
    node = calloc(sizeof(node_t), 1);
    node->value = calloc(sizeof(value_t), 1);
    memcpy(node->value, val, sizeof(value_t));


    node->right = read_tree_node( pos*2, buf);
    node->left = read_tree_node(pos*2 +1, buf);

    return node;
}




