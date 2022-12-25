%{
void yyerror (char *s);
int yylex();
#include <stdio.h>     /* C declarations used in actions */
#include <stdlib.h>
#include <ctype.h>
#include "signatures.h"
struct query_tree tree = {0};
struct comparator* cmp;
size_t vtype;
void append_val_setting(char* field, uint64_t val);
void print_tree();
void set_cur_operation(uint8_t operation);
void set_cur_value(char* field, uint64_t val);
void switch_filter();
void set_comp();
%}

%union {uint64_t num; char *string;}         /* Yacc definitions */
%token DB
%token FIND
%token INSERT
%token DELETE
%token UPDATE
%token PARENT
%token SET
%token OR
%token LT
%token LET
%token GT
%token GET
%token NE
%token OPBRACE
%token CLBRACE
%token OPCBRACE
%token CLCBRACE
%token OPSQBRACE
%token CLSQBRACE
%token COLON
%token DOLLAR
%token <string> QUOTE
%token COMMA
%token <num> FALSE
%token <num> TRUE
%token <string> STRING
%token <num> NUMBER
%type <num> bool value operation comp

%%

mongosh: DB FIND OPBRACE OPCBRACE filters CLCBRACE CLBRACE {print_tree();}
	  |
	  DB DELETE OPBRACE OPCBRACE filters CLCBRACE CLBRACE
	  |
	  DB INSERT OPBRACE parent_def COMMA vals_def CLBRACE {print_tree();}
	  |
	  DB UPDATE OPBRACE OPCBRACE filters CLCBRACE COMMA DOLLAR SET COLON vals_def CLBRACE
	  ;

parent_def : OPCBRACE PARENT COLON NUMBER CLCBRACE;

vals_def : OPCBRACE set_vals CLCBRACE;

filters : filter {switch_filter();}| filter COMMA filters {switch_filter();};

filter : STRING COLON value {set_cur_operation(0); set_cur_value($1, $3);}
	 |
	 STRING COLON operation {set_cur_value($1, $3);}
	 |
	 DOLLAR OR OPSQBRACE filter COMMA filter CLSQBRACE {set_comp();}
	 ;

operation: OPCBRACE DOLLAR comp COLON value CLCBRACE {set_cur_operation($3); $$ = $5;};

set_vals : set_val
	   |
	   set_val COMMA set_vals

set_val : STRING COLON value {append_val_setting($1, $3);};

value : QUOTE STRING QUOTE {vtype = STRING_T; $$ = $2;}
	|
	NUMBER {vtype = INTEGER_T; $$ = $1;}
	|
	bool {vtype = BOOLEAN_T; $$ = $1;}
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
	return yyparse ( );
}

void append_val_setting(char* field, uint64_t val){
	struct field_value_pair fv = {.field = field, .value = val};
	struct value_setting* vs = malloc(sizeof(struct value_setting));

	vs->fv = fv;

	if (tree.settings)
		vs->next = tree.settings;
	else
		vs->next = NULL;
	tree.settings = vs;

}

void set_cur_operation(uint8_t operation){
	struct comparator* tmp = malloc(sizeof(struct comparator));
	tmp->next = cmp;
	cmp = tmp;
	cmp->operation = operation;

//	struct comparator* cmp = malloc(sizeof(struct comparator));
//	cmp->operation = operation;
//
//	if (tree.filters){
//		cmp->next = tree.filters->comp_list;
//		tree.filters->comp_list = cmp;
//	}
//	else{
//		struct filter* f = malloc(sizeof(struct filter));
//		f->next = NULL;
//		f->comp_list = cmp;
//		cmp->next = NULL;
//		tree.filters = f;
//	}
}

void set_cur_value(char* field, uint64_t val){
	struct field_value_pair fv = {.field = field, .value = val};
//	tree.filters->comp_list->fv = fv;
	cmp->fv = fv;
}

void switch_filter(){
	struct comparator* tmp;
	struct filter* f = malloc(sizeof(struct filter));
        f->next = tree.filters;

	if (tree.filters){
		if (tree.filters->comp_list){
			tmp = tree.filters->comp_list;
			tree.filters->comp_list = malloc(sizeof(struct comparator));
			tree.filters->comp_list->next = tmp;
			tree.filters->comp_list->operation = cmp->operation;
			tree.filters->comp_list->fv = cmp->fv;
		}else{
			tree.filters->comp_list = malloc(sizeof(struct comparator));
			tree.filters->comp_list->operation = cmp->operation;
			tree.filters->comp_list->fv = cmp->fv;
		}
	}
	else{
		f->comp_list = cmp;
	}

	cmp = cmp->next;
	tree.filters = f;
}

void set_comp(){
	if (tree.filters)
		tree.filters->comp_list = cmp;
	else{
		struct filter* f = malloc(sizeof(struct filter));
		f->comp_list = cmp;
		f->next = NULL;
		tree.filters = f;
	}
	cmp = cmp->next;
	tree.filters->comp_list->next = NULL;
}

void print_tree(){
	while (tree.filters){
		while (tree.filters->comp_list){
			char* field = tree.filters->comp_list->fv.field;
			uint64_t value = tree.filters->comp_list->fv.value;
			printf("%s %d %lu\n", field, tree.filters->comp_list->operation, value);
			tree.filters->comp_list = tree.filters->comp_list->next;
		}
		printf("\n");
		tree.filters = tree.filters->next;
	}
//	while (tree.settings){
//		printf("%s = %s\n", tree.settings->fv.field, tree.settings->fv.value);
//		tree.settings = tree.settings->next;
//	}
}

void yyerror (char *s) {fprintf (stderr, "%s\n", s);}