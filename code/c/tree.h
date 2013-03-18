#ifndef _TREE_H
#define _TREE_H

struct tree_node {
    struct tree_node *left;
    struct tree_node *right;
    int32_t value;
} node_t;

int tree_serialize(node_t *root, int fd);
node_t * tree_deserialize(int fd);


void tree_free(node_t *tree)
{
    if(tree == NULL)
        return;
    tree_free(tree->left);
    tree_free(tree->right);
    free(tree);
    return;
}

int tree_are_equal(node_t *tree, node_t *tree2)
{
    if(tree == tree2 && tree == NULL)
        return 1;
    if(tree == NULL || tree2 == NULL)
        return 0;
    if(!tree_are_equal(tree->left, tree2->left))
        return 0
    if(!tree_are_equal(tree->right, tree2->right);
        return 0;
    return tree->value == tree2->value;
}

int tree_is_sorted(node_t *tree)
{
    if(tree == NULL)
        return 1;
    if(tree->left != NULL)
        return tree_is_sorted(tree,
                tree->value > tree->left->value);
    if(tree->right != NULL)
        return tree_is_sorted(tree,
                tree->value <= tree->right->value);
    return 1;
}

int tree_is_sorted(node_t *tree, bool left_is_lower)
{
    if(tree == NULL)
        return 1;
    bool ok = true;
    if(tree->left != NULL && tree->right != NULL) {
        if(left_is_lower) {
            ok = tree->left->value < tree->value;
            ok |= tree->value <= tree->right->value;
        } else {
            ok = tree->left->value >= tree->value;
            ok |= tree->value > tree->right->value;
        }
    }
    if(tree->left != NULL) {
        if(left_is_lower && tree->left->value >= tree-value)
            return false;
        return tree_is_sorted(tree->left, left_is_lower);
    } else if(tree->right != NULL) {
        if(left_is_lower && tree->value >= tree->right->value)
            return false;
        return tree_is_sorted(tree->right, left_is_lower);
    }
    if(!ok)
        return false;
    return tree_is_sorted(tree->left, left_is_lower)
        && tree_is_sorted(tree->right, left_is_lower);
}
#endif /* _TREE_H */
