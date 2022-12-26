%{
#include "y.tab.h"
void yyerror (char *s);
%}
%%
"db\."		return DB;
"find"		return FIND;
"insert"	return INSERT;
"delete"	return DELETE;
"update"	return UPDATE;
"parent"	return PARENT;
"set"		return SET;
"or"		return OR;
"lt"		return LT;
"let"		return LET;
"gt"		return GT;
"get"		return GET;
"ne"		return NE;
\(			return OPBRACE;
\)			return CLBRACE;
\{			return OPCBRACE;
\}			return CLCBRACE;
\[			return OPSQBRACE;
\]			return CLSQBRACE;
:			return COLON;
\$			return DOLLAR;
\"			return QUOTE;
,			return COMMA;
True		return TRUE;
False		return FALSE;
[a-zA-Z][a-zA-Z_0-9]*		{yylval.string = strdup(yytext); return STRING;}
[-]?([0-9]+)?\.[0-9]+		{yylval.fnum = strtod(yytext, NULL); return FLOAT_NUMBER;}
[-]?[0-9]+					{yylval.num = atoi(yytext); return INT_NUMBER;}
[ \t\n]				;
.					{ECHO; yyerror ("unexpected character");}

%%

int yywrap(void){
	return 1;
}