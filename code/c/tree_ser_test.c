#include <stdio.h>

#include "tree.h"

/*
   serialization format:
   binary array, breath first format.
   |special_tag|root|root_left|root_right|...|

*/

/*   4
    /  \
   2    7
  / \  / \
 1  3  6  8
 */
node_t * create_tree_0()
{
    node_t * node;
    node_t * root;
    node = calloc(sizeof(node_t), 1);

    node->value = 4;
    root = node;


    node->left = calloc(sizeof(node_t), 1);
    node->right = calloc(sizeof(node_t), 1);

    node = root->left;
    node->value = 2;

    node->left = calloc(sizeof(node_t), 1);
    node->right = calloc(sizeof(node_t), 1);
    node->left->value = 1;
    node->right->value = 3;

    node = root->right;
    node->value = 7;
    node->left = calloc(sizeof(node_t), 1);
    node->right = calloc(sizeof(node_t), 1);
    node->left->value = 6;
    node->right->value = 8;

    return root;
}

/*   4
    / \
   2   7
   \   /
    3 6
 */
node_t * create_tree_1()
{
    node_t * node;
    node_t * root;
    node = calloc(sizeof(node_t), 1);

    node->value = 4;
    root = node;

    node->left = calloc(sizeof(node_t), 1);
    node->right = calloc(sizeof(node_t), 1);

    node = root->left;
    node->value = 2;

    node->right = calloc(sizeof(node_t), 1);
    node->right->value = 3;

    node = root->right;
    node->value = 7;
    node->left = calloc(sizeof(node_t), 1);
    node->left->value = 6;

    return root;
}

/*   4
      \
       7
        \
         8
 */
node_t * create_tree_2()
{
    node_t * node;
    node_t * root;
    node = calloc(sizeof(node_t), 1);

    node->value = 4;
    root = node;

    node->right = calloc(sizeof(node_t), 1);

    node = root->right;
    node->value = 7;
    node->right = calloc(sizeof(node_t), 1);
    node->right->value = 8;

    return root;
}





int test_tree(node_t *tree, int id)
{
    char name[10];
    int fd;
    node_t *rtree;

    sprintf(name, "tree%d.d",id);
    fd = open(name, O_RDWR);
    tree_serialize(tree, fd);
    fseek(fd, 0, SEEK_SET);
    rtree = tree_deserialize(fd);
    close(fd);

    if(!tree_are_equal(tree, rtree))
        perror("fail!");

    tree_free(rtree);
    tree_free(tree);
}

int main()
{
    test_tree(create_tree_0(), 0);
    test_tree(create_tree_1(), 1);
    test_tree(create_tree_2(), 2);
}




