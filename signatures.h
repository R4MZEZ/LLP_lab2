#include <stdint.h>
#define STRING_T 0
#define INTEGER_T 1
#define FLOAT_T 2


struct query_tree{
    uint8_t command;
    struct filter* filters;
    struct value_setting* settings;
};

struct filter{
    struct filter* next;
    struct comparator* comp_list;
};

struct field_value_pair{
    char* field;
    uint8_t val_type;
    uint64_t int_value;
    float real_value;
};

struct comparator{
    struct comparator* next;
    uint8_t operation;
    struct field_value_pair fv;
};

struct extended_comparator{
    struct extended_comparator* next;
    struct extended_comparator* connected;
    uint8_t operation;
    struct field_value_pair fv;
};

struct value_setting{
    struct value_setting* next;
    struct field_value_pair fv;
};


