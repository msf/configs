#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void rev_word(char *str, unsigned start, unsigned stop)
{
    unsigned i, len = stop - start;
    char tmp;

    if(len < 0) return;
    for(i = 0; i < len/2; i++) {
        tmp = str[ start + i ];
        str[ start +i] = str[ stop -i];
        str[ stop -i] = tmp;
    }
    return;
}

char * my_strtok(char *str, char tok) {
    int x = 0;

    return strtok(str, tok);

    unsigned i=0;
    while( str[i] != '\0') {
        if (str[i] == tok)
            x = 1; //mark token found
        else if( x== 1)
            return str+i; // start of new substr
        i++;
    }
    return '\0';
}

/* print a sequence of chars, followed by space */
int print_word(char *s, unsigned start, unsigned end)
{
    unsigned len = end - start;
    unsigned i;
    if( len <= 0)
        return len;
    for(i=start; i < end; i++)
        fputc(s[i], stdout);
    fputc(' ', stdout);
    fflush(stdout);
    return len;
}


struct list {
    char *word;
    unsigned word_len;
    struct list *next;
};

void rev_text_2(char *text)
{
    char tmp;
    unsigned i, j, len;

    len = strlen(text);
    for(i=0; i < (len/2); i++) {
        tmp = text[i];
        text[i] = text[len-i-1];
        text[len-i-1] = tmp;
    }
    j = 0;
    for(i=0; i < len; i++) {
        if( text[i] == ' ') {
            rev_word(text, j, i-1);
            print_word(text,j, i-1);
            j = i+1;
        }
    }
    print_word("\n", 0, 1);
}


void rev_text_1(char *text)
{
    char *pos = NULL;
    char *next = NULL;
    struct list *tmp = NULL;
    struct list *rev = NULL;

    pos = text;
    do {
        tmp = calloc(1, sizeof(struct list));
        next = my_strtok(pos, ' ');
        tmp->word = pos;
        tmp->word_len = (unsigned) (next - pos) -1;
        tmp->next = rev;
        rev = tmp;
        pos = next;
    } while( pos != NULL );

    while( rev != '\0' ) {
        print_word( rev->word, 0, rev->word_len);
        tmp = rev;
        rev = rev->next;
        free(tmp);
    }
    print_word("\n", 0, 1);
}


int main(void) {
    char text[2048];

    do {
        gets(text);
        rev_text_1(text);
        rev_text_2(text);

    } while (text[0] != 0);

    return 0;
}
