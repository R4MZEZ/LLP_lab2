%{
void yyerror (char *s);
int yylex();
#include <stdio.h>     /* C declarations used in actions */
#include <stdlib.h>
#include <ctype.h>
#include "signatures.h"
struct query_tree tree = {0};
size_t vtype;
void append_val_setting(char* field, uint64_t val);
void print_tree();
%}

%union {uint64_t num; char *string;}         /* Yacc definitions */
%token DB
%token DOT
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
%type <string> comp
%type <num> bool value

%%

mongosh: DB DOT FIND OPBRACE OPCBRACE filters CLCBRACE CLBRACE
	  |
	  DB DOT DELETE OPBRACE OPCBRACE filters CLCBRACE CLBRACE
	  |
	  DB DOT INSERT OPBRACE parent_def COMMA vals_def CLBRACE {print_tree();}
	  |
	  DB DOT UPDATE OPBRACE OPCBRACE filters CLCBRACE COMMA DOLLAR SET COLON vals_def CLBRACE
	  ;

parent_def : OPCBRACE PARENT COLON NUMBER CLCBRACE;

vals_def : OPCBRACE set_vals CLCBRACE;

filters : filter | filter COMMA filters;

filter : STRING COLON value
	 |
	 STRING COLON operation
	 |
	 PARENT COLON NUMBER
	 |
	 DOLLAR OR OPSQBRACE filters CLSQBRACE
	 ;

operation: OPCBRACE DOLLAR comp COLON value CLCBRACE;

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

comp : LT {$$ = "<";}
       |
       LET {$$ = "<=";}
       |
       GT {$$ = ">";}
       |
       GET {$$ = ">=";}
       |
       NE {$$ = "!=";}
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

void print_tree(){
	while (tree.settings){
		printf("%s = %s\n", tree.settings->fv.field, tree.settings->fv.value);
		tree.settings = tree.settings->next;
	}
}

void yyerror (char *s) {fprintf (stderr, "%s\n", s);}