%{
void yyerror (char *s);
int yylex();
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "signatures.h"

struct query_tree tree = {0};
struct extended_comparator* cmp;
size_t vtype;
size_t size = 0;

void print_tree();
void set_cur_operation(uint8_t operation);
void set_cur_value(char* field, uint64_t val, double fval);
void append_val_setting(char* field, uint64_t val, double fval);
void switch_filter();
void set_comp();
void set_command(uint8_t command);
void *test_malloc(size_t size_of);
void print_ram();
%}

%union {uint64_t num; char *string; float fnum;}
%token DB
%token FIND INSERT DELETE UPDATE
%token <string> PARENT STRING
%token SET OR
%token LT LET GT GET NE
%token OPBRACE CLBRACE
%token OPCBRACE CLCBRACE
%token OPSQBRACE CLSQBRACE
%token COLON DOLLAR COMMA QUOTE
%token <num> FALSE TRUE INT_NUMBER
%token <fnum> FLOAT_NUMBER
%type <num> bool value operation comp

%%

syntax: mongosh {print_tree();};

mongosh: DB FIND OPBRACE OPCBRACE filters CLCBRACE CLBRACE {set_command(0);}
	  |
	  DB DELETE OPBRACE OPCBRACE filters CLCBRACE CLBRACE {set_command(1);}
	  |
	  DB INSERT OPBRACE parent_def COMMA vals_def CLBRACE {set_command(2);}
	  |
	  DB UPDATE OPBRACE OPCBRACE filters CLCBRACE COMMA DOLLAR SET COLON vals_def CLBRACE {set_command(3);}
	  ;

parent_def : OPCBRACE PARENT COLON INT_NUMBER CLCBRACE {set_cur_operation(0);
							vtype = INTEGER_T;
							set_cur_value("parent", $4, 0);
							switch_filter();};

vals_def : OPCBRACE set_vals CLCBRACE;

filters : filter {switch_filter();} | filter COMMA filters {switch_filter();};

filter : STRING COLON value {
				set_cur_operation(0);
				float val;
				if (vtype == FLOAT_T){
					memcpy(&val, &$3, sizeof(uint64_t));
					set_cur_value($1, 0, val);
				}else
					set_cur_value($1, $3, 0);

			}
	 |
	 STRING COLON operation {set_cur_value($1, $3, 0);}
	 |
	 DOLLAR OR OPSQBRACE filter COMMA filter CLSQBRACE {set_comp();}
	 ;

operation: OPCBRACE DOLLAR comp COLON value CLCBRACE {set_cur_operation($3); $$ = $5;};

set_vals : set_val
	   |
	   set_val COMMA set_vals

set_val : STRING COLON value {
				if (vtype == FLOAT_T){
					float val;
					memcpy(&val, &$3, sizeof(uint64_t));
					append_val_setting($1, 0, val);
				}else
					append_val_setting($1, $3, 0);

                             };

value : QUOTE STRING QUOTE {vtype = STRING_T; $$ = $2;}
	|
	INT_NUMBER {vtype = INTEGER_T; $$ = $1;}
	|
	FLOAT_NUMBER {vtype = FLOAT_T; memcpy(&$$, &$1, sizeof(uint64_t));}
	|
	bool {vtype = INTEGER_T; $$ = $1;}
	;

bool : TRUE {$$ = 1;}
       |
       FALSE {$$ = 0;}
       ;

comp : LT {$$ = 1;}
       |
       LET {$$ = 2;}
       |
       GT {$$ = 3;}
       |
       GET {$$ = 4;}
       |
       NE {$$ = 5;}
       ;
%%                     /* C code */

int main (void) {
	return yyparse ();
}



void *test_malloc(size_t size_of){
    size += size_of;
    return malloc(size_of);
}

void print_ram(){
    printf("RAM USAGE: %zu bytes\n", size);
}

void append_val_setting(char* field, uint64_t val, double fval){
	struct value_setting* vs = test_malloc(sizeof(struct value_setting));
	struct field_value_pair fv = {.field = field, .val_type = vtype};
	fv.real_value = fval;
	fv.int_value = val;
	vs->fv = fv;
	vs->next = tree.settings;
	tree.settings = vs;

}

void set_cur_operation(uint8_t operation){
	struct extended_comparator* tmp = test_malloc(sizeof(struct extended_comparator));
	tmp->next = cmp;
	tmp->operation = operation;
	cmp = tmp;

}

void set_cur_value(char* field, uint64_t val, double fval){
	struct field_value_pair fv = {.field = field, .val_type = vtype};
	fv.real_value = fval;
	fv.int_value = val;
	cmp->fv = fv;
}

void switch_filter(){
	struct filter* f = test_malloc(sizeof(struct filter));
	struct comparator* tmp = test_malloc(sizeof(struct comparator));
        f->next = tree.filters;

        if (cmp->connected){
		tmp->next = test_malloc(sizeof(struct comparator));
		tmp->next->operation = cmp->connected->operation;
		tmp->next->fv = cmp->connected->fv;
	}
	tmp->operation = cmp->operation;
	tmp->fv = cmp->fv;

	if (tree.filters)
		tree.filters->comp_list = tmp;
	else{
		f->comp_list = tmp;
		tree.filters = f;
		f = test_malloc(sizeof(struct filter));
		f->next = tree.filters;
	}

	cmp = cmp->next;
	tree.filters = f;
}

void set_comp(){
	struct extended_comparator* tmp = NULL;
	tmp = cmp->next->next;
	cmp->connected = cmp->next;
	cmp->next = tmp;
}

void set_command(uint8_t command){
	tree.command = command;
}

void print_tree(){
	printf("COMMAND: %x\n", tree.command);
	size_t filter_count = 0;
	size_t comp_count = 0;
	printf(" FILTERS:\n");
	while (tree.filters){
		if (tree.filters->comp_list)
			printf("  FILTER %zu:\n", filter_count++);
		while (tree.filters->comp_list){
			char* field = tree.filters->comp_list->fv.field;
			uint64_t value = tree.filters->comp_list->fv.int_value;
			float fvalue = tree.filters->comp_list->fv.real_value;
			printf("   COMPARATOR %zu:\n", comp_count++);
			printf("    FIELD '%s'\n    OPERATION '%d'\n", field, tree.filters->comp_list->operation);
			switch(tree.filters->comp_list->fv.val_type){
				case STRING_T: printf("    VALUE '%s'\n", value); break;
				case INTEGER_T: printf("    VALUE '%d'\n", value); break;
				case FLOAT_T: printf("    VALUE '%f'\n", fvalue); break;
			}
			tree.filters->comp_list = tree.filters->comp_list->next;
		}
		printf("\n");
		comp_count = 0;
		tree.filters = tree.filters->next;
	}
	if (tree.settings)
		printf(" SETTINGS: \n");
	while (tree.settings){
		printf("  FIELD '%s'\n", tree.settings->fv.field);
		switch(tree.settings->fv.val_type){
			case STRING_T: printf("  VALUE '%s'\n", tree.settings->fv.int_value); break;
			case INTEGER_T: printf("  VALUE '%lu'\n", tree.settings->fv.int_value); break;
			case FLOAT_T: printf("  VALUE '%f'\n", tree.settings->fv.real_value); break;
		}
		printf("\n");
		tree.settings = tree.settings->next;
	}

	print_ram();
}

void yyerror (char *s) {fprintf (stderr, "%s\n", s);}